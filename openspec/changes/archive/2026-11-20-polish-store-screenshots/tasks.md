# Tasks

## 1. Layout fixes and store set (PR 1)

- [x] 1.1 Size `Browse.Chips` to its chips; check iPhone Live and Guide on a simulator, with and without a channel playing
- [x] 1.2 Start the iPad and Mac guide rows under the time labels in a short group
- [x] 1.3 Give the details panel and the list header a two-line fallback and a one-line Up next time column; check iPad Live in English and Spanish
- [x] 1.4 Add the geometry checks to `LiveUITests`, `GuideUITests` and `GuideRegularUITests`, and run those classes on a local iPhone and iPad simulator
- [x] 1.5 Add `scripts/make-store-art.py`, the art it draws, and the shelf fixtures' poster and backdrop addresses in store-shot mode
- [x] 1.6 Pin the store-shot clock at 9:41 and align the store guide to the wall clock's half hour
- [x] 1.7 Add `AntennaMacJourneys`, the `AntennaMac` scheme, the Mac window size and the Mac steps in the `App screenshots` workflow and the export script
- [x] 1.8 Leave `StoreArt-*.jpg` out of Release and check a Release iOS build holds neither the clip nor the art
- [x] 1.9 Update `docs/conventions.md` and `docs/release/store-listing.md`

## 2. Verify

- [x] 2.1 Run the workflow on the branch, download `store-screenshots`, and look at every locale's iPhone, iPad, Mac and Apple TV pictures
- [x] 2.2 Each changed requirement has a test citing it, and `scripts/check-spec-refs.sh` passes
- [x] 2.3 `/opsx:verify polish-store-screenshots` passes, then archive the change
