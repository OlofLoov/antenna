## Context

Boards, under `openspec/specs/design-system/boards/`: `TV-Movies.dc.html` and `TV-Search.dc.html` (the tab bar as drawn there), `TV-Shell-Menu.dc.html`, `TV-Shell-FocusedTab.dc.html`, `TV-Shell-Loading.dc.html`, `TV-Shell-Empty.dc.html`, `TV-Shell-Guide-Menu.dc.html` (the bar over the Guide, the shell's clock hidden and its space kept), `TV-Shell-Loading-Menu.dc.html` and `TV-Shell-Empty-Menu.dc.html` (the bar over the loading and empty screens, Retry without its highlight), and `TV-Settings.dc.html` (Settings as it opens, first row focused). Nothing is left undrawn.

Design-system requirements that apply: "Live video keeps playing under overlays", "Focus is the lifted white card", "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums", "Nothing shows before the paywall" and "Loading shows real progress per step".

Follows decision adr-0001 (hardware playback path for MPEG-TS), decision adr-0002 (SwiftData with private CloudKit for sync), decision adr-0003 (credentials in iCloud Keychain), decision adr-0005 (AntennaCore is UI-free), decision adr-0006 (no free tier, paid unlock only) and decision adr-0009 (keep per-device state in UserDefaults). tvOS only.

## Goals / Non-Goals

**Goals:**
- One Menu contract every Apple TV screen can rely on.
- Launch straight into the last channel.

**Non-Goals:**
- Tab contents, Settings contents, the purchase screen and the Top Shelf.

## Decisions

- `ShellView`, `ShellModel`, `ShellNavigator` and `LastChannelKey` live in `Apps/Shared/Views/Shell/` under `#if os(tvOS)` and are tested in the AntennaTV bundle; nothing enters AntennaCore. `add-first-run-onboarding` owns the root chooser; `RootView` stays the root elsewhere until `add-live-tv-on-iphone-ipad-mac` ships.
- `ShellNavigator` is an environment object with `show(.search)`, `show(.guide(programmeKey:))` and `showLive()`; a request from the overlay dismisses it first.
- Last channel: a `LastChannelKey(sourceID, channelID)` in `UserDefaults` under `shell.lastChannel`, per device and not synced, written when the zap bar's channel-change event fires. No SwiftData field (decision adr-0002). The key, the event payload and logs never carry the stream URL, which holds Xtream credentials (decision adr-0003).
- Launch deadline: 10 seconds from the shell appearing and again on Retry, accepted for v1, to revisit with device measurements on a 30,000-stream Xtream source. Until it passes, another source finishing does not tune. If loading the channel throws, that tune is not retried and the stored key is kept.
- Menu contract: a content screen deeper than its root handles Menu itself; at root the shell's handler receives it. The shell never asks content for its depth. The overlay, info bar and number box handle Menu while visible.
- The pause timer runs while Settings is open over a content tab.
- One clock on screen: over the Guide the shell's clock hides and the guide's shows. The clock uses the locale's hour-minute style.
- Deviations from the design system: video pauses behind content tabs ("Live video keeps playing under overlays"); the current tab is white-filled when focus is in the content and falls back to the surface fill at weight 600 when the bar has focus ("Focus is the lifted white card"); tab pills are 51 pt and the gear 56 pt ("Targets are large enough to hit"); the scrim is 0.55 with an opaque `#11151C` pill group ("Text meets contrast minimums"); completed loading rows show an accent check ("One accent color"); the loading container is a focus holder with no focus token.
- Tested against a fake conforming to the existing `PlaybackEngine` protocol; the real engine, its error view and live-edge resume come from `add-playback-engine`.
- Moved to the plan during review: selecting the open Guide tab returns to the guide, selecting the open Movies, Series or Search tab goes to its first item, and swipe down over the Guide and over the loading and empty screens.
- Dropped: "never exits to Home", an untestable universal claim replaced by the scope line on leaving the app.
- Decided: Menu keeps the user in the app; the TV button leaves.

## Risks / Trade-offs

- The 10-second launch deadline is unmeasured on large Xtream sources.
- All sources removed while a tab is open hands over to onboarding; a lapsed purchase hands over to the purchase screen.
