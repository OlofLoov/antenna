#!/usr/bin/env python3
"""String Catalog checks and sync for Antenna.

check [catalog ...]
    Fails when a key that should be translated has no text, or an incomplete
    plural set, in a language listed in Config/languages, or when a key is
    marked stale. LANGUAGES="en ar" overrides the list. Needs no Xcode.

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


def check(paths):
    langs = languages()
    targets = [pathlib.Path(p).resolve() for p in paths] if paths else catalogs()
    problems = []
    for path in targets:
        problems += check_catalog(path, langs)
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
