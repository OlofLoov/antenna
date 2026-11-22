## Why

Title order treats every accented letter as its plain letter, so "Ängel" sits
among the A titles. A Swedish or Finnish user expects Å, Ä and Ö after Z, and
a Danish or Norwegian user expects Æ, Ø and Å there. The owner asked for the
Swedish order.

## What Changes

- Title and Year order put the letters a language's alphabet adds after Z,
  in that alphabet's order, when the device language is Swedish, Finnish,
  Danish or Norwegian.
- Every other language keeps folding accents, so "Émile" stays with the E
  titles.

## Capabilities

### Modified Capabilities

- `movies-and-series-browsing`: Browse a genre or sort the lot gains a
  scenario for those letters.

## Impact

`Packages/AntennaCore/Sources/AntennaCore/Shelf/ShelfGrid.swift` and its tests.
Sorting still works out one key per title, so 100 000 titles sort as fast as
before.
