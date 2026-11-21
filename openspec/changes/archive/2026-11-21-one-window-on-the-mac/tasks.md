## 1. One window

- [x] 1.1 `OpenWindows` and `OneWindowCommands` on the Mac: New Window opens the `main` window group only while none is open
- [x] 1.2 The root view sends files, links and Handoff to the open window on the Mac
- [x] 1.3 "New Window" in the String Catalog in every language in `Config/languages`
- [x] 1.4 The iPad build declares no multiple-scene support (checked in the built Info.plist)

## 2. Verify

- [x] 2.1 The requirement this change adds has a test citing `live-tv-on-iphone-ipad-mac/one-window-on-the-mac`
- [x] 2.2 `OneWindowTests` runs in the `App screenshots` workflow and passes there
- [x] 2.3 /opsx:verify passes
