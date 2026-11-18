# Tasks

## 1. Live behind Movies, Series and Search

- [x] 1.1 `ShellModel.open` pauses a playing, loading or reconnecting channel when a content tab opens from Live or Guide, and starts the 30-second stop timer
- [x] 1.2 The timer stops the engine; Live or Guide resumes a paused channel or tunes a stopped one again
- [x] 1.3 A load that finishes behind a content tab stays paused
- [x] 1.4 `ShellModelTests` and `ShellNavigationTests` for each scenario; `testMoviesPausesLiveAndLiveResumesIt`; the Search UI tests expect the channel paused behind Search

## 2. The group column

- [x] 2.1 Group rows other than the shown one, locked groups and Search take no focus while focus is outside the column
- [x] 2.2 The open and shown-group scrolls run without animation
- [x] 2.3 `testMovingBetweenTheColumnsInALargeCatalogue` checks the column does not move

## 3. Verify

- [x] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 3.2 `/opsx:verify` passes
