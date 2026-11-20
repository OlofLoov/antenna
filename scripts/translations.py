#!/usr/bin/env python3
"""String Catalog checks and sync for Antenna.

check [catalog ...]
    Fails when a key that should be translated has no text, or an incomplete
    plural set, in a language listed in Config/languages, or when a key is
    marked stale. LANGUAGES="en ar" overrides the list. Needs no Xcode.
    Counts get their own rules: a number before a noun is an Int with
    plural forms in English and so in every language, never text (%@) and
    never a separate "1 <noun>" key. Without catalog arguments it also reads
    the Swift sources, where a count sentence must resolve to such a key.

sync EXPORT_DIR
    Copies the catalogs Xcode synced into an exported .xcloc back into the
    repo, drops stale keys and marks keys without words as not translated.

missing EXPORT_DIR
    Fails when the exported catalogs hold a key the repo's catalogs lack,
    which means code gained a string without a catalog sync.
"""

import json
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LANGUAGES_FILE = ROOT / "Config" / "languages"
SEARCH_DIRS = ["Apps", "Packages"]

# CLDR plural categories each language must fill. Xcode may offer more
# (Spanish, French and Portuguese "many"); those are allowed, not required.
REQUIRED_PLURALS = {"ar": {"zero", "one", "two", "few", "many", "other"}}
DEFAULT_PLURALS = {"one", "other"}

# Info.plist keys that name the app. The name is "Antenna" in every language.
UNTRANSLATED_KEYS = {"CFBundleName", "CFBundleDisplayName"}

# Nouns a count stands before. A key with "%@ <noun>" or "1 <noun>" fails;
# "%lld <noun>" needs plural forms.
COUNT_NOUNS = {
    "channel", "favorite", "source", "group", "title", "episode", "season", "day", "hour", "minute", "second",
    "login", "connection", "programme", "guide", "entry", "movie", "reminder", "tile", "profile", "result", "item",
}
COUNT_PLURALS = {"entry": "entries"}
COUNT_WORDS = {COUNT_PLURALS.get(n, n + "s") for n in COUNT_NOUNS}

# Keys whose count is never one, so English has a single form. The code
# names the one-item case with a different sentence.
COUNT_NEVER_ONE = {
    "Guide id “%@” is not in any of the %lld guides",
    "None of the %lld guides for %@ lists “%@”. Pick an entry below.",
}

INT_BEFORE_NOUN = re.compile(r"%(\d+\$)?(lld|ld|d)\s+(more\s+)?([A-Za-z]{3,})\b")
TEXT_BEFORE_NOUN = re.compile(r"%(\d+\$)?@\s+(more\s+)?([A-Za-z]+)\b")
ONE_BEFORE_NOUN = re.compile(r"(?<![\d.,])\b1\s+(more\s+)?([A-Za-z]+)\b")

FORMAT = re.compile(r"%(\d+\$)?[-+ #0']*\d*(\.\d+)?(ll|l|h|hh|q|z|t|j)?[@dDiuUxXoOfeEgGcCsSpaAF%]|\$\{[^}]*\}")


def languages():
    override = os.environ.get("LANGUAGES")
    if override:
        return override.split()
    if not LANGUAGES_FILE.exists():
        return ["en"]
    return [line.strip() for line in LANGUAGES_FILE.read_text().splitlines() if line.strip()]


def catalogs():
    found = []
    for top in SEARCH_DIRS:
        for path in sorted((ROOT / top).rglob("*.xcstrings")):
            if any(part.startswith(".") for part in path.relative_to(ROOT).parts):
                continue
            found.append(path)
    return found


def has_words(key):
    return any(ch.isalpha() for ch in FORMAT.sub("", key))


def should_translate(key, entry):
    if entry.get("shouldTranslate") is False:
        return False
    return key not in UNTRANSLATED_KEYS and has_words(key)


def unit_problems(node, required, where):
    """Walks a localization and names each gap: empty units and short plural sets."""
    problems = []
    if not isinstance(node, dict):
        return problems
    unit = node.get("stringUnit")
    if unit is not None and not str(unit.get("value", "")).strip():
        problems.append(f"{where}: empty text")
    string_set = node.get("stringSet")
    if string_set is not None and not any(str(v).strip() for v in string_set.get("values", [])):
        problems.append(f"{where}: empty phrase list")
    variations = node.get("variations", {})
    plural = variations.get("plural")
    if plural is not None:
        missing = sorted(required - set(plural))
        if missing:
            problems.append(f"{where}: plural forms missing: {', '.join(missing)}")
        for form, child in plural.items():
            problems += unit_problems(child, required, f"{where} [{form}]")
    for kind, cases in variations.items():
        if kind == "plural":
            continue
        for case, child in cases.items():
            problems += unit_problems(child, required, f"{where} [{kind} {case}]")
    for name, sub in node.get("substitutions", {}).items():
        problems += unit_problems(sub, required, f"{where} {{{name}}}")
    if unit is None and string_set is None and not variations and "substitutions" not in node:
        if "argNum" not in node:
            problems.append(f"{where}: no text")
    return problems


def count_problems(key, entry, source):
    """Names a count that cannot pick the language's plural form
    (localization/counts-use-the-language-s-plural-forms)."""
    problems = []
    text = TEXT_BEFORE_NOUN.search(key)
    if text and text.group(3).lower() in COUNT_WORDS:
        problems.append("a count passed as text (%@) cannot pick a plural form, pass the Int")
    one = ONE_BEFORE_NOUN.search(key)
    if one and one.group(2).lower() in COUNT_NOUNS:
        problems.append('a separate "1 <noun>" key misses the other plural forms, use the %lld key\'s plural variations')
    number = INT_BEFORE_NOUN.search(key)
    if number and number.group(4).lower().endswith("s") and key not in COUNT_NEVER_ONE:
        english = entry.get("localizations", {}).get(source)
        if english is None or "plural" not in json.dumps(english):
            problems.append("a count before a noun needs plural forms in English, and so in every language")
    return problems


def check_catalog(path, langs):
    data = json.loads(path.read_text())
    source = data.get("sourceLanguage", "en")
    rel = path.relative_to(ROOT)
    problems = []
    for key, entry in data.get("strings", {}).items():
        if entry.get("extractionState") == "stale":
            problems.append(f"{rel}: {key!r}: stale, remove it or sync the catalog")
            continue
        if not should_translate(key, entry):
            continue
        problems += [f"{rel}: {key!r}: {p}" for p in count_problems(key, entry, source)]
        localizations = entry.get("localizations", {})
        for lang in langs:
            required = REQUIRED_PLURALS.get(lang, DEFAULT_PLURALS)
            if lang == source:
                if lang in localizations:
                    problems += [f"{rel}: {key!r} [{lang}] {p}" for p in unit_problems(localizations[lang], required, "")]
                continue
            if lang not in localizations:
                problems.append(f"{rel}: {key!r} [{lang}]: no translation")
                continue
            source_node = localizations.get(source, {})
            source_plural = "plural" in json.dumps(source_node)
            node = localizations[lang]
            if source_plural and "plural" not in json.dumps(node):
                problems.append(f"{rel}: {key!r} [{lang}]: English has plural forms, this language has none")
            problems += [f"{rel}: {key!r} [{lang}] {p}" for p in unit_problems(node, required, "")]
    return problems


# Swift sources whose copy resolves in a catalog, and the catalogs it may
# resolve in. App code reaches the Core catalog through Words.
SOURCE_SCOPES = [
    (["Apps/Shared", "Apps/Mobile", "Apps/TV"], ["Apps/Shared", "Packages/AntennaCore/Sources"]),
    (["Packages/AntennaCore/Sources"], ["Packages/AntennaCore/Sources"]),
]
# Lines that never reach the screen: logs and debug descriptions.
NOT_COPY = re.compile(r"\b(log|logger|Logger|print|debugPrint|NSLog|description|debugDescription)\b")
# A count formatted to a String before it reaches the sentence, such as
# `text.count(n)` or `n.formatted()`. The catalog key then holds %@.
TEXT_COUNT = re.compile(r"\bformatted\(|\bString\(|\btext\.count\(|\.description\b")
# Where a file's preview code starts: a #Preview, or a fixture named preview….
PREVIEW_START = re.compile(r"#Preview|PreviewFixtures|\b(let|var)\s+preview\w*")


def swift_literals(text):
    """Yields (line, column, parts) for each string literal. Parts alternate
    literal text and interpolated code, and start and end with text."""
    i, line, n = 0, 1, len(text)
    while i < n:
        if text.startswith("//", i):
            end = text.find("\n", i)
            i = n if end < 0 else end
            continue
        if text.startswith("/*", i):
            end = text.find("*/", i)
            end = n if end < 0 else end
            line += text.count("\n", i, end)
            i = end + 2
            continue
        if text[i] == "\n":
            line += 1
        if text[i] != '"':
            i += 1
            continue
        start_line, column = line, i - (text.rfind("\n", 0, i) + 1)
        multi = text.startswith('"""', i)
        i += 3 if multi else 1
        parts, buf = [], []
        while i < n:
            if multi and text.startswith('"""', i):
                i += 3
                break
            if not multi and text[i] in '"\n':
                line += text[i] == "\n"
                i += 1
                break
            if text[i] == "\\" and i + 1 < n:
                nxt = text[i + 1]
                if nxt == "(":
                    depth, j = 1, i + 2
                    while j < n and depth:
                        if text[j] == "(":
                            depth += 1
                        elif text[j] == ")":
                            depth -= 1
                        elif text[j] == '"':
                            close = text.find('"', j + 1)
                            j = n - 1 if close < 0 else close
                        j += 1
                    parts += ["".join(buf), text[i + 2 : j - 1]]
                    buf = []
                    i = j
                    continue
                if nxt == "\n":
                    line += 1
                    i += 2
                    while i < n and text[i] in " \t":
                        i += 1
                    continue
                buf.append(text[i : i + 2])
                i += 2
                continue
            if text[i] == "\n":
                line += 1
                buf.append(" ")
                i += 1
                while i < n and text[i] in " \t":
                    i += 1
                continue
            buf.append(text[i])
            i += 1
        parts.append("".join(buf))
        if multi:
            parts[0] = parts[0].lstrip()
            parts[-1] = parts[-1].rstrip()
        yield start_line, column, parts


def catalog_keys(dirs):
    """Every key in the catalogs under `dirs`, and whether English varies it by plural."""
    keys = {}
    for top in dirs:
        for path in sorted((ROOT / top).rglob("*.xcstrings")):
            if any(part.startswith(".") for part in path.relative_to(ROOT).parts):
                continue
            data = json.loads(path.read_text())
            source = data.get("sourceLanguage", "en")
            for key, entry in data.get("strings", {}).items():
                english = entry.get("localizations", {}).get(source)
                keys[key] = english is not None and "plural" in json.dumps(english)
    return keys


def counted(parts):
    """The indexes of the interpolations that stand before a count noun."""
    found = []
    for index in range(1, len(parts), 2):
        after = re.match(r"\s+(more\s+)?([A-Za-z]+)\b", parts[index + 1])
        if after and after.group(2).lower() in COUNT_WORDS:
            found.append(index)
    return found


def literal_problem(parts, verbatim, keys):
    literal = "".join(p if i % 2 == 0 else "\\(…)" for i, p in enumerate(parts))
    for i in range(0, len(parts), 2):
        one = ONE_BEFORE_NOUN.search(parts[i])
        if one and one.group(2).lower() in COUNT_NOUNS:
            return f'"{literal}": pass the count to the plural key instead of spelling 1'
    counts = counted(parts)
    if not counts:
        return None
    if any(TEXT_COUNT.search(parts[i]) for i in counts):
        return f'"{literal}": the count arrives formatted as text, which cannot pick a plural form, pass the Int'
    pattern = ""
    for i, part in enumerate(parts):
        if i % 2 == 0:
            pattern += re.escape(part)
        else:
            pattern += "%lld" if i in counts else "%(lld|@|lf|f|\\.\\d+f)"
    regex = re.compile(pattern + r"\Z")
    matches = [k for k in keys if regex.match(k)]
    if verbatim or not matches:
        return f'"{literal}": a count sentence outside the catalog, make it a LocalizedStringResource (or Words) with the Int'
    if not all(keys[k] or k in COUNT_NEVER_ONE for k in matches):
        return f'"{literal}": its key has no English plural forms'
    return None


def source_problems():
    """Count sentences in Swift that do not resolve to a catalog key with an
    Int count: built as plain text, passed as text, or spelled "1 <noun>".
    Previews and everything after the first #Preview in a file are skipped."""
    problems = []
    for dirs, catalog_dirs in SOURCE_SCOPES:
        keys = catalog_keys(catalog_dirs)
        for top in dirs:
            for path in sorted((ROOT / top).rglob("*.swift")):
                rel = path.relative_to(ROOT)
                text = path.read_text()
                lines = text.splitlines()
                preview = next((n for n, l in enumerate(lines, 1) if PREVIEW_START.search(l) and "@Environment" not in l), None)
                for line, column, parts in swift_literals(text):
                    if preview is not None and line >= preview:
                        continue
                    code = lines[line - 1] if line <= len(lines) else ""
                    before = lines[line - 2] if line >= 2 else ""
                    if NOT_COPY.search(code) or NOT_COPY.search(before):
                        continue
                    verbatim = re.search(r"verbatim(\(|:\s*)$", code[:column])
                    problem = literal_problem(parts, verbatim is not None, keys)
                    if problem:
                        problems.append(f"{rel}:{line}: {problem}")
    return problems


def check(paths):
    langs = languages()
    targets = [pathlib.Path(p).resolve() for p in paths] if paths else catalogs()
    problems = []
    for path in targets:
        problems += check_catalog(path, langs)
    if not paths:
        problems += source_problems()
    for problem in problems:
        print(f"FAIL {problem}")
    print(f"{'FAIL' if problems else 'ok  '} translations: {len(targets)} catalogs, languages {' '.join(langs)}")
    return 1 if problems else 0


def write_catalog(path, data):
    text = json.dumps(data, indent=2, ensure_ascii=False, sort_keys=True, separators=(",", " : "))
    path.write_text(text + "\n")


def exported_catalogs(export_dir):
    out = {}
    for xcloc in pathlib.Path(export_dir).glob("*.xcloc"):
        contents = xcloc / "Source Contents"
        for path in contents.rglob("*.xcstrings"):
            out[str(path.relative_to(contents))] = path
    return out


def sync(export_dir):
    for rel, exported in sorted(exported_catalogs(export_dir).items()):
        target = ROOT / rel
        if not target.exists():
            print(f"skip {rel}: no catalog in the repo")
            continue
        data = json.loads(exported.read_text())
        strings = data.get("strings", {})
        # The export holds the source language only. Translations come from
        # the repo's catalog, which the export rewrites in place and keeps.
        source = data.get("sourceLanguage", "en")
        current = json.loads(target.read_text()).get("strings", {})
        for key, entry in strings.items():
            for lang, node in current.get(key, {}).get("localizations", {}).items():
                if lang != source:
                    entry.setdefault("localizations", {})[lang] = node
        for key in [k for k, v in strings.items() if v.get("extractionState") == "stale"]:
            del strings[key]
        for key, entry in strings.items():
            if key in UNTRANSLATED_KEYS or not has_words(key):
                entry["shouldTranslate"] = False
        write_catalog(target, data)
        print(f"sync {rel}: {len(strings)} keys")
    return 0


def missing(export_dir):
    problems = []
    for rel, exported in sorted(exported_catalogs(export_dir).items()):
        keys = json.loads(exported.read_text()).get("strings", {})
        target = ROOT / rel
        if not target.exists():
            extra = sorted(k for k in keys if k not in UNTRANSLATED_KEYS)
            problems += [f"{rel}: {k!r}: no catalog holds this string" for k in extra]
            continue
        known = json.loads(target.read_text()).get("strings", {})
        problems += [f"{rel}: {k!r}: in code, not in the catalog" for k in sorted(set(keys) - set(known))]
        problems += [f"{rel}: {k!r}: stale" for k, v in keys.items() if v.get("extractionState") == "stale"]
    for problem in problems:
        print(f"FAIL {problem}")
    if problems:
        print("Run scripts/sync-strings.sh and commit the catalogs.")
    print(f"{'FAIL' if problems else 'ok  '} catalogs hold every string in code")
    return 1 if problems else 0


def main(argv):
    if not argv or argv[0] not in {"check", "sync", "missing"}:
        print(__doc__)
        return 2
    command, rest = argv[0], argv[1:]
    if command == "check":
        return check(rest)
    if len(rest) != 1:
        print(f"{command} takes the export directory")
        return 2
    return sync(rest[0]) if command == "sync" else missing(rest[0])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
