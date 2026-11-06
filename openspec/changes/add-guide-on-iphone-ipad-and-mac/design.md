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
