# Tasks

## 1. Fix

- [ ] 1.1 `LiveModel.listed` set when a catalogue built from loaded channels lands; `LiveStatus` reads loading until then
- [ ] 1.2 `ShellModel.liveScreen` is `.empty` only when every source added nothing
- [ ] 1.3 `ShellModel.listed` and `channelsPending`; the Apple TV Guide reads "Loading channels" while channels may still arrive
- [ ] 1.4 Unit tests: a loaded source reads as loading while its catalogue builds, Apple TV's Live shows loading while the title watched last waits, and the Guide waits for the catalogue

## 2. Verify

- [ ] 2.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 2.2 `/opsx:verify` passes
