## Context

`Shelf.sortKey` folds case and accents and compares keys with `<`, so 100 000
titles sort without locale-aware compares (speed-up-large-libraries). Folding
drops the dots and rings Swedish counts as letters of their own.

## Decisions

- **Placeholders after z.** Before folding, the alphabet's extra letters
  become `{`, `|` and `}`, the three bytes after `z`, in the alphabet's order.
  Keys stay plain strings compared with `<`. A real brace or bar in a title
  sorts as one of those letters, which no title list will notice.
- **The language picks the alphabet.** `Locale.current.language` is read once
  per sort, not once per title. Swedish and Finnish use Å Ä Ö, Danish and
  Norwegian (`da`, `nb`, `nn`, `no`) use Æ Ø Å. Region does not count: English
  in Sweden sorts as English, as Finder does.
- **Options considered.** `localizedStandardCompare` per pair was the 1.5 s
  sort the earlier change removed. ICU sort keys are not public in Foundation.

## Boards

None. No screen changes.
