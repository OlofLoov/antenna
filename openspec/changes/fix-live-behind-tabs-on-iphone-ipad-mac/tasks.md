# Tasks

## 1. The shared hold

- [ ] 1.1 `LiveHold` in `Apps/Shared/Player` takes the pause, the 30-second stop and the resume out of `ShellModel+Hold.swift`; the timer stops only a channel still paused
- [ ] 1.2 `ShellModel` runs on `LiveHold`, with `heldByShell` and `pausedByShell` as before; `ShellModelTests` pass

## 2. iPhone, iPad and Mac

- [ ] 2.1 `LiveModel.opened(_:)` queues each tab change; Movies, Series and Search begin the hold, Live and the Guide end it, Settings leaves it
- [ ] 2.2 Picture in Picture and AirPlay keep the channel playing; the window ending behind Movies begins the hold
- [ ] 2.3 A load that lands behind Movies, Series or Search stays paused
- [ ] 2.4 Multi-view ends with the selected tile, and full screen ends, when the hold begins
- [ ] 2.5 `LiveHoldTests` for each scenario; `ShelfPlayerUITests.testMoviesPausesLiveAndLiveResumesIt` with the Live probe on Movies

## 3. Verify

- [ ] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 3.2 `/opsx:verify` passes
