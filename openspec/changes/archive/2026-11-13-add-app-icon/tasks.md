## 1. Proposal and board

- [x] 1.1 Write the proposal, delta specs, design and tasks, and validate with `openspec validate add-app-icon --strict`
- [x] 1.2 Draw `App-Icon-Concepts` with three concepts, their appearances and small sizes, and the Apple TV layers for the recommended one

## 2. Build the icon

- [x] 2.1 Add the SVG sources in `design/icon/` and `scripts/render-icons.sh` with `scripts/render-svg.swift`
- [x] 2.2 Add `Apps/Mobile/AppIcon.icon` and wire it into the Antenna target in `project.yml`
- [x] 2.3 Add `Apps/TV/Assets.xcassets` with the App Icon & Top Shelf Image brand assets and wire it into the AntennaTV target
- [x] 2.4 Build iOS, macOS and tvOS and check the built apps hold the icon
- [x] 2.5 Export ictool previews and show them on the board
- [x] 2.6 Add the icon test in AntennaCore citing `app-release/every-app-shows-its-icon` and `app-release/the-icon-follows-the-home-screen-appearance`

## 3. Verify

- [x] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [x] 3.2 `/opsx:verify` passes
