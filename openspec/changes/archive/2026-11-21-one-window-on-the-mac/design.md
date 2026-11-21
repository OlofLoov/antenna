# Design

## Context

`AntennaApp` declares one `WindowGroup`. On the Mac that adds File > New
Window (Command-N), and each window builds its own `RootView`, whose
`LiveModel`, `ShelfLibrary`, `ShelfPlayback` and `SearchModel` are
`@State`. A second window downloaded and indexed every source again and
opened a second provider connection. A `WindowGroup` with no
`handlesExternalEvents` can also open a new window for an opened file or
link on the Mac.

The iPad build's Info.plist has no `UIApplicationSupportsMultipleScenes`
(the generated scene manifest is empty), so iPadOS gives the app one
scene. Checked in the built `Antenna.app/Info.plist`.

Boards: the File menu is the system's and has no board. The item keeps
the system's name and shortcut. Design-system requirements are unchanged.

## Decisions

### How to keep one window

Options:
1. `CommandGroup(replacing: .newItem) {}` alone. No New Window at all.
   A viewer who closes the window can get it back only from the Dock, and
   the CI journey's Command-N fallback for a runner that starts with no
   window stops working.
2. A `Window` scene on the Mac. One window by construction, but the app
   quits when that window closes, and the scene content would be declared
   twice, once per platform.
3. Replace New Window with an item that opens the window group only while
   no window is open, and dim it otherwise.
4. Move the libraries to app scope so windows share them. Larger, and two
   windows would still play two channels on one account.

Chosen: 3. `OpenWindows` counts root views on screen through
`onAppear` and `onDisappear`; `OneWindowCommands` reads it. The window
group gets the id `main` so `openWindow(id:)` can open it.
`handlesExternalEvents(preferring: ["*"], allowing: ["*"])` on the root
view sends every file, link and Handoff to the open window.

"New Window" is our string now, so it is in the String Catalog with the
names macOS uses in each language.

### Pinning it

`OneWindowTests` in `AntennaMacJourneys` launches the app, presses
Command-N with a window open and expects one window and a dimmed item,
then closes the window and expects Command-N to open one. A step of its
own in the nightly `App screenshots` workflow runs it; a local run needs
the Mac to allow UI automation, which an unattended machine refuses.
