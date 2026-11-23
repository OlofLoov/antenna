#!/usr/bin/env python3
"""App Store listing checks for Antuna (add-store-localization).

The listing lives in fastlane/metadata/<store-locale>/<field>.txt, the
layout fastlane deliver reads. Nothing here talks to App Store Connect.

check [--root DIR]
    Fails when a language in Config/languages has no listing, a field is
    missing, empty or over Apple's limit, keywords are badly formed, the
    copy names a provider or another site, or the description leaves out
    that the app has no channels and needs a purchase.

locales [--root DIR] [--all] [CODE ...]
    Prints one line per app language: code, region for -AppleLocale, and
    its store locales separated by commas. Without codes it lists the ready
    languages: English and those in Config/reviewed-languages. --all lists
    every language, held ones included.

held [--root DIR]
    Prints the app languages whose listing is held until their review.
"""

import pathlib
import re
import sys

# App language -> (region for screenshots, App Store locales).
STORE_LOCALES = {
    "en": ("en_US", ["en-US"]),
    "sv": ("sv_SE", ["sv"]),
    "de": ("de_DE", ["de-DE"]),
    "es": ("es_MX", ["es-ES", "es-MX"]),
    "fr": ("fr_FR", ["fr-FR", "fr-CA"]),
    "pt-BR": ("pt_BR", ["pt-BR"]),
    "ar": ("ar_SA", ["ar-SA"]),
}

# App Store Connect's limits, in characters.
LIMITS = {
    "name": 30,
    "subtitle": 30,
    "keywords": 100,
    "promotional_text": 170,
    "description": 4000,
    "release_notes": 4000,
}
URL_FIELDS = ["privacy_url", "support_url"]
TEXT_FIELDS = ["name", "subtitle", "description", "keywords", "promotional_text", "release_notes"]
SITE = "https://antuna.app/"

# Providers, broadcasters, leagues, streaming services and other players.
# App Review 5.2.3 and 2.3.7: the listing names none of them.
NAMES = [
    "netflix", "hulu", "disney", "hbo", "espn", "dazn", "bein", "sky sports", "bbc",
    "cnn", "fox", "nbc", "cbs", "canal+", "movistar", "youtube", "twitch", "prime video",
    "peacock", "paramount", "nfl", "nba", "nhl", "mlb", "uefa", "fifa", "premier league",
    "laliga", "la liga", "bundesliga", "champions league", "ligue 1", "tivimate",
    "smarters", "gse", "vlc", "infuse", "plex", "kodi", "ppv", "pay-per-view",
]
SITE_LIKE = re.compile(r"(https?://|www\.|\b[\w-]+\.(com|net|org|tv|io|me|xyz|se|info|cc)\b)", re.IGNORECASE)

# Words for "free" and for content, per app language, to catch a promise of
# free channels or of an amount of them.
FREE = {
    "en": r"free",
    "sv": r"gratis",
    "de": r"kostenlos\w*|gratis",
    "es": r"gratis|gratuit[oa]s?",
    "fr": r"gratuit\w*",
    "pt-BR": r"grátis|gratuit[oa]s?",
    "ar": r"مجان\w*",
}
CONTENT = {
    "en": r"channels?|tv|movies|films",
    "sv": r"kanaler|tv|filmer",
    "de": r"sender|kanäle|tv|filme",
    "es": r"canales|tv|televisión|películas",
    "fr": r"chaînes|tv|télé|films",
    "pt-BR": r"canais|tv|filmes",
    "ar": r"قنوات|قناة|تلفزيون|أفلام",
}

# What each description must say: no channels of its own, and a purchase.
MUST_SAY = {
    "en": [r"no channels", r"purchase"],
    "sv": [r"inga kanaler", r"köp"],
    "de": [r"keine Sender", r"Kauf"],
    "es": [r"ningún canal", r"compra"],
    "fr": [r"aucune chaîne", r"achat"],
    "pt-BR": [r"nenhum canal", r"compra"],
    "ar": [r"أي قنوات", r"شراء"],
}


def read_codes(path):
    if not path.exists():
        return []
    return [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def field(folder, name):
    path = folder / f"{name}.txt"
    if not path.exists():
        return None
    return path.read_text(encoding="utf-8").rstrip("\n")


def words(text):
    return {w.casefold() for w in re.findall(r"\w+", text)}


def check_locale(code, locale, folder, errors):
    where = f"{locale}"
    values = {}
    for name in TEXT_FIELDS + URL_FIELDS:
        value = field(folder, name)
        if value is None:
            errors.append(f"{where}: {name}.txt is missing")
            continue
        if not value.strip():
            errors.append(f"{where}: {name}.txt is empty")
            continue
        if value != value.strip():
            errors.append(f"{where}: {name}.txt starts or ends with spaces")
        values[name] = value
    for name, limit in LIMITS.items():
        value = values.get(name)
        if value is not None and len(value) > limit:
            errors.append(f"{where}: {name} is {len(value)} characters, the limit is {limit}")
    if "name" in values and len(values["name"]) < 2:
        errors.append(f"{where}: name must have at least 2 characters")
    for name in URL_FIELDS:
        value = values.get(name)
        if value is not None and not value.startswith(SITE):
            errors.append(f"{where}: {name} must start with {SITE}")

    keywords = values.get("keywords")
    if keywords is not None:
        seen = set()
        taken = words(values.get("name", "")) | words(values.get("subtitle", ""))
        for keyword in keywords.split(","):
            if keyword != keyword.strip():
                errors.append(f"{where}: keyword '{keyword}' has a space around it, which spends the limit")
            keyword = keyword.strip().casefold()
            if not keyword:
                errors.append(f"{where}: keywords have an empty entry")
                continue
            if keyword in seen:
                errors.append(f"{where}: keyword '{keyword}' is listed twice")
            seen.add(keyword)
            if keyword in taken:
                errors.append(f"{where}: keyword '{keyword}' is already in the name or subtitle")

    free = FREE.get(code)
    content = CONTENT.get(code)
    for name in TEXT_FIELDS:
        value = values.get(name)
        if value is None:
            continue
        lowered = value.casefold()
        for banned in NAMES:
            if re.search(rf"(?<!\w){re.escape(banned)}(?!\w)", lowered):
                errors.append(f"{where}: {name} names '{banned}'")
        for match in SITE_LIKE.finditer(value):
            errors.append(f"{where}: {name} carries an address, '{match.group(0)}'")
        if free and content:
            near = rf"(?<!\w)({free})(?!\w)\W+(\w+\W+){{0,2}}?({content})(?!\w)|(?<!\w)({content})\W+(\w+\W+){{0,2}}?({free})(?!\w)"
            for match in re.finditer(near, lowered):
                errors.append(f"{where}: {name} promises free content, '{match.group(0)}'")
            amount = rf"\d{{2,}}[\d.,  ]*\+?\s*({content})(?!\w)"
            for match in re.finditer(amount, lowered):
                errors.append(f"{where}: {name} promises an amount of content, '{match.group(0)}'")

    description = values.get("description")
    if description is not None:
        for phrase in MUST_SAY.get(code, []):
            if not re.search(phrase, description, re.IGNORECASE):
                errors.append(f"{where}: description must say '{phrase}' (no channels of its own, purchase required)")


def check(root):
    errors = []
    metadata = root / "fastlane" / "metadata"
    languages = read_codes(root / "Config" / "languages")
    if "en" not in languages:
        errors.append("Config/languages: en is missing")
    wanted = {}
    for code in languages:
        if code not in STORE_LOCALES:
            errors.append(f"{code}: no App Store locale for this app language in scripts/store_metadata.py")
            continue
        for locale in STORE_LOCALES[code][1]:
            wanted[locale] = code
    for locale, code in wanted.items():
        folder = metadata / locale
        if not folder.is_dir():
            errors.append(f"{locale}: no listing for app language {code} (fastlane/metadata/{locale})")
            continue
        check_locale(code, locale, folder, errors)
    if metadata.is_dir():
        for folder in sorted(p for p in metadata.iterdir() if p.is_dir()):
            if folder.name not in wanted:
                errors.append(f"{folder.name}: listing for a language the app does not ship")
    for error in errors:
        print(f"store-metadata: {error}", file=sys.stderr)
    if errors:
        return 1
    ready, held = split(root)
    print(f"store-metadata: {len(wanted)} listings pass; ready: {' '.join(ready)}; held: {' '.join(held) or 'none'}")
    return 0


def split(root):
    languages = read_codes(root / "Config" / "languages")
    reviewed = set(read_codes(root / "Config" / "reviewed-languages")) | {"en"}
    ready = [c for c in languages if c in reviewed]
    held = [c for c in languages if c not in reviewed]
    return ready, held


def locales(root, codes, every):
    if not codes:
        ready, held = split(root)
        codes = ready + (held if every else [])
    for code in codes:
        if code not in STORE_LOCALES:
            print(f"store-metadata: unknown app language {code}", file=sys.stderr)
            return 1
        region, stores = STORE_LOCALES[code]
        print(f"{code} {region} {','.join(stores)}")
    return 0


def main(argv):
    args = argv[1:]
    root = pathlib.Path(__file__).resolve().parent.parent
    if "--root" in args:
        index = args.index("--root")
        root = pathlib.Path(args[index + 1]).resolve()
        del args[index : index + 2]
    every = "--all" in args
    args = [a for a in args if a != "--all"]
    if not args:
        print(__doc__, file=sys.stderr)
        return 64
    command, rest = args[0], args[1:]
    if command == "check":
        return check(root)
    if command == "locales":
        return locales(root, rest, every)
    if command == "held":
        print(" ".join(split(root)[1]))
        return 0
    print(__doc__, file=sys.stderr)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv))
