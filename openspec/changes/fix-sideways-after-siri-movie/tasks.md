# Tasks

## 1. Fix

- [x] 1.1 `SidewaysLive.sideways` is false while a movie or episode plays, so closing it fills the screen again
- [x] 1.2 A movie ending with Live open calls `LiveModel.appeared()`, so the stopped channel plays again
- [x] 1.3 `-ui-testing-intent-on-return` hands a Siri request over when the app returns to the foreground, Debug only
- [x] 1.4 UI test: a movie from Siri over a sideways channel, closed, gives the channel back full screen

## 2. Verify

- [x] 2.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 2.2 `/opsx:verify` passes
