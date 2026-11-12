# Design

## Context

Boards: `openspec/specs/design-system/boards/iPad-Guide.dc.html`, `iPhone-Guide.dc.html`, `iPad-Guide-Placeholders.dc.html`, `iPad-Guide-Empty.dc.html`, `iPhone-Guide-Placeholders.dc.html`, `iPhone-Guide-Detail.dc.html`.

Design-system requirements that apply: "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "Channel rows share one anatomy", "A current programme always shows its progress", "Channels without a logo show initials", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums", "Nothing shows before the paywall", "Loading shows real progress per step".

Not drawn yet: details for a past, later, gap or placeholder programme; the empty group on iPhone; the loading and error states; the folded sidebar; other zoom levels and grayed-out zoom buttons; the now-playing chip without the live dot; nothing playing.

## Goals / Non-Goals

**Goals:**
- Reuse the Apple TV guide layout with this guide's sizes, so both guides share one layout function.
- The guide never drives playback except through Watch.

**Non-Goals:**
- A picture inside the guide.
- Remembering scroll position and open details when the user comes back from Live.

## Decisions

- Other changes provide: the Apple TV guide's layout function takes column width, minimum block width and channel column width as parameters (tvOS keeps 370, 40, 300), and its row identifiers use `RowKey.identifierToken`. The shell's `ShellNavigator` compiles for every platform and gains a `currentGroup` setter. Live provides the navigator on these platforms and keeps the engine alive while the Guide is shown. Search calls `show(.guide(programmeKey:))`. `RowKey.identifierToken` is a stable digest of `sourceID`, `id` and position.
- Owner's numbers: 180 pt per 30 minutes by default, zoom steps 90, 120, 180, 270; 200 pt channel column; blocks narrower than 28 pt widen and push the next one right, with 4 pt gaps. The window starts at the half-hour at or before now minus 30 minutes, or at or before now when the grid is too narrow to show the line. Mac minimum window 640 pt with the grid at least 440. iPhone cards 168 by 54 pt.
- The zoom level lives in an injected per-device store (production `UserDefaults`), never SwiftData. A pinch snaps to the nearest step.
- Identifiers use the `guide.` prefix and `RowKey.identifierToken`, never `Channel.id` or a stream URL. A UI test asserts that no `guide.*` identifier contains the scheme, host or query of any fixture stream URL.
- Engine calls: Watch on a channel not loaded or failed calls `load` once; paused calls `play` once; playing or loading calls nothing. The guide itself makes no engine call. The fake engine offers `load`, `play`, `pause`, `stop` and a state of idle, loading, playing, paused or failed.
- Banners: a dismissed source does not come back from a replayed event but does on a new failure. No banner for a source with no channel on this device. A waiting banner clears within five seconds of the guide loading.
- Board deviations: channel cells show number, logo and name only (deviates from "Channel rows share one anatomy"); the now line stands in for progress bars in the grid (deviates from "A current programme always shows its progress"); the iPhone NOW badge (11 pt) and initials (9 pt) (deviate from "Text stays above the platform caption floor"); the 34 pt iPhone header tap area and 30 pt day chips in a 44 pt row (deviate from "Targets are large enough to hit").
- Performance budget: only visible items plus one row and column of slack are laid out. With 20 000 channels and seven days, first rows within one second on iPhone 15 and iPad (M1), and no hitch longer than one frame while scrolling.
- Columns are absolute half hours anchored on a local boundary. The DST core test uses a fixed time zone and a 2027-03-28 fixture shared with the Apple TV guide. Keyboard requirements run in CI on macOS and by hand on iPad.
- The grid opens half an hour back (tvOS opens 90 minutes back), and the Mac toolbar uses the iPad sizes.

## Risks / Trade-offs

These were decided without an interview. The owner answers each one that changes a requirement before the change is accepted.

- Open question: iPhone gets per-channel rows instead of a narrow grid. Changes "One row per channel on iPhone".
- Open question: Guide and Live share the current group instead of the guide keeping its own. Changes "The same group as Live".
- Open question: the channel keeps playing with no picture instead of a picture-in-picture box like the Apple TV guide's. Changes "Playback carries on out of sight".
- Open question: should a later programme picked in Search open this guide on iPhone, iPad and Mac, instead of playing the channel with a "Later" line as `add-search` does today? Changes "Open at a programme" and needs `add-search` revised.
- Open question: Watch on a later programme plays the channel now and notes the programme, since reminders are not built. Changes "Start watching from the guide".
- Open question: zoom has four fixed steps kept per device. Changes "Zoom".
- Open question: the filter is on iPad and Mac only. Changes "Filter channels by typing".
- Open question: the iPhone row header's tap area is under the 44 pt floor. Can be decided during implementation.
- Open question: should the guide remember its scroll position and open details when the user comes back from Live? Would add a requirement.

## Implementation decisions

Calls made while building, recorded here instead of asked.

- `GuideRowLayout.blocks` takes a `GuideScale` (column width, minimum block, channel column). `GuideScale.television` is 370, 40 and 300 and is the default, so the Apple TV grid and its tests did not change. `GuideZoom` holds the four steps and the 28 pt minimum and 200 pt channel column.
- Row identifiers use the existing `RowKey.identifier`, `<sourceID>.<position>`. It never holds `Channel.id` or a stream link, and the Apple TV guide's tests already read it, so no separate `identifierToken` was added. UI tests on iPad check that no `guide.*` identifier holds `file:`, `fixture` or `?` from the fixture stream links.
- `ShellNavigator` and `ProgrammeKey` compile on every platform, and the navigator gained `setGroup`. On iPhone, iPad and Mac the tab bar and the sidebar each provide one; Search uses it to open the Guide. Apple TV's `setGroup` goes through the channel overlay's `tuned(from:)`.
- The window root owns one `GuideBoardModel`: the time in view, zoom, filter, open details, keyboard cursor and a pending programme from another screen. The layout that takes over on a size change opens on the tab the session store last recorded (`add-session-restore-and-recently-watched`), so it opens on the Guide. A popover that goes because the grid gave way to the rows leaves the details open for the sheet.
- The grid is one scroll view in both axes whose content spans the guide's bounds at the zoom's width. `GuideViewport` picks the rows and half hours on screen plus one each way, rounded so the rows rebuild only when a row or a column comes into view. The header, the pinned channel column and the now line follow the scroll offset every frame. A programme whose start is scrolled off keeps its title at the grid's left edge.
- The scroll view appears once its size is known, already at the opening point: SwiftUI ignored a scroll asked for during the first layout pass.
- A guide that loads or refreshes while open can move the bounds' start; the grid moves its offset by the same amount, so the same time stays in view.
- Zoom keys are Command-= (Command-+ on a keyboard that has it) and Command-−. A pinch on iPad snaps to the nearest step when it ends; there is no live scaling while the fingers move. The step is in `UserDefaults` under `guide.zoom`. UI tests start from the default with `-ui-testing-reset-guide-zoom`.
- The filter uses the catalogue's `rows(in:matching:)` with a `ChannelFilter`, so a name matches word by word and digits match the start of the number, as in Live's list and Search. It folds the group's names on each change of the filter text; an empty filter skips that. Its count is the group title's count, and picking another group clears it.
- Keyboard: the arrows move a ring between blocks and Return opens the details; the details' Escape and dismiss gestures are the system popover's. Watch has no Return shortcut, because the details component also compiles for tvOS, where key shortcuts do not exist.
- Gaps and placeholders open nothing in the grid, and gap cards open nothing on iPhone; only programmes have details.
- On iPhone, Today returns the rows to now; another day starts each row at the programme on at the same time of day. Each row reads 24 hours of programmes from there. The row header keeps the board's 34 pt tap area.
- The failed-guide banner is per source, from the guide state of that source's first channel; Retry asks the guide store to refresh that source. A dismissed banner stays hidden until that source stops failing, so a later failure shows it again.
- Later programmes from Search: on iPhone, iPad and Mac the Guide opens at the programme with its details, as this change's open question proposed. Watch there plays the channel now with the Later line Search used to show. See the spec conflict below.
- On Mac the Guide asks for a 640 pt wide window, which leaves the grid at least 440 pt.
- The UI test script gives Live's scripted guide its programmes and a horizon. `-ui-testing-narrow-on-details` turns the window narrow a second after the details open, because a tap on the layout switch would close the popover first. `-ui-testing-guide days` adds a programme tomorrow and two days of guide; `-ui-testing-guide failed` fails Cabin's guide until Retry.

### Spec conflict

`add-search`'s "Pick a programme" requirement says a later programme picked on iPhone, iPad or Mac plays its channel and shows it as Later. This change's "Open at a programme" says Search opens this guide at it, and this change's proposal says `add-search` needs revising. The app now follows this change. `add-search`'s spec text is left as it is for the owner to reconcile; its UI tests for that scenario now cite this change's requirements.
