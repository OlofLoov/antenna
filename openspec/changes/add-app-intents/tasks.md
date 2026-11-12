# Tasks

## 1. References and matching in AntennaCore

- [x] 1.1 Take the stream link out of M3U channel ids, and verify a parser test with a login in the link (done in change `fix-m3u-channel-ids`)
- [x] 1.2 Add channel and title references that parse every shipped format and never hold a link or login, and verify round-trip and redaction tests
- [x] 1.3 Add channel lookup by reference and matching by folded name or number prefix, and verify tests for case, accents, numbers, ties and the 50 000 channel benchmark
- [x] 1.4 Add the reply text for every failure, and verify tests that no reply holds a URL, port, status or code

## 2. Suggestions and lookup

- [x] 2.1 Suggest favorites then other channels, and titles in progress then My list, leaving out locked, hidden and missing items, and verify an integration test
- [x] 2.2 Resolve saved references with a per-item failure and a 10-second background load of only the referenced source, and verify integration tests for each failure and for two requests sharing one load

## 3. Actions

- [x] 3.1 Add Tune Channel that brings Antenna forward on Live and tunes nothing when refused, and verify integration and UI tests
- [x] 3.2 Add Play Title that resumes a movie or opens a series, and verify an integration test
- [x] 3.3 Add Open Search with and without a query, and verify integration and UI tests including a query of only spaces
- [x] 3.4 Add Toggle Favorite with add, remove and toggle modes running in the background, and verify integration tests for each reply and for nothing playing
- [x] 3.5 Refuse every action before unlock or without sources, and verify integration tests for both replies
- [ ] 3.6 Add the five Siri phrases and refresh their parameters after catalogue and favorites changes, and verify on an iPhone lock screen (code done; open because a spoken Siri phrase needs a real iPhone, and none is available)

## 4. Platforms

- [x] 4.1 Exclude every action from the Apple TV target with a rules grep, and verify the tvOS build in CI
- [ ] 4.2 Run all four actions from the Shortcuts app on a Mac with Antenna closed and playing, and record the result (code done; open because no Mac run of Shortcuts was possible here, and the macOS build on main fails in OnboardingForm.swift)

## 5. Verify

- [ ] 5.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 5.2 `/opsx:verify` passes
