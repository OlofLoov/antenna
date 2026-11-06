# Design

## Context

See proposal.md for why. The bar and number box sit over the tvOS player from `tvos-shell`, read channels and numbers from `channel-catalogue` and programmes from `guide-data`.

Boards, under `openspec/specs/design-system/boards/`: `TV-ZapBar.dc.html`, `TV-ZapBar-Hidden.dc.html`, `TV-ZapBar-NoProgramme.dc.html`, `TV-ZapBar-GuideLoading.dc.html`, `TV-ZapBar-GuideUnavailable.dc.html`, `TV-ZapBar-NoNext.dc.html`, `TV-ZapBar-NoCatchup.dc.html`, `TV-ZapBar-Favorites.dc.html`, `TV-ZapBar-AllChannels.dc.html`, `TV-ZapBar-PillNoMatch.dc.html`, `TV-ZapBar-PillZeros.dc.html`, `TV-ZapBar-PillNoChannel.dc.html`, `TV-ZapBar-EndsNow.dc.html`, `TV-ZapBar-Buffering.dc.html`, `TV-ZapBar-LiveOnly.dc.html`. Nothing is left undrawn.

Design-system requirements that apply: “Live video keeps playing under overlays”, “One accent color”, “Text stays above the platform caption floor”, “A current programme always shows its progress”, “Channels without a logo show initials”, “Accessibility identifiers follow the board”, “Nothing fake and nothing bundled”, “Text meets contrast minimums”.

Decisions this builds on: adr-0001 (hardware playback path for MPEG-TS), adr-0002 (SwiftData with private CloudKit for sync), adr-0003 (credentials in iCloud Keychain), adr-0005 (AntennaCore is UI-free).

User flow: any channel change shows the bar for five seconds. With the bar hidden, play/pause shows it again. Menu hides it. Swiping up or down changes channel in the group. Select while the bar shows hides it and opens the channel overlay. On a keyboard, typing digits shows the box with the matching name; two seconds after the last digit, or on Return, Antenna tunes.

## Goals / Non-Goals

**Goals:**
- Formatting rules live in the core package so the overlay and bar show the same words.

**Non-Goals:**
- A setting for the five-second delay.
- Changing group by swiping left or right.
- A clock in full-screen playback. The clock belongs to the overlay and the shell.

## Decisions

- Needs change `add-playback-engine` for an observable engine state and a `PresentationInfo` stream (video height, audio channels, codec). Until then the quality requirement runs against a fake engine.
- Remaining-time text, progress fraction (clamped to 0...1, full for a zero or negative duration) and the badge mappings are pure AntennaCore functions. The channel overlay's panel uses the same formatter. Minutes round up. Under 60 s, including zero and negative, is "Ends now".
- Resolution: at least 2160 is "4K", 1080 is "1080p", 720 is "720p", lower is absent. Audio: 8 channels "7.1", 6 "5.1", 2 "Stereo", 1 "Mono", other counts absent, codec prefix when known. Their arrival does not restart the hide timer.
- Current group: a tune from the overlay's column for group H makes H current. Tuning by number, search, guide or onboarding to a channel outside the current group keeps the group, and the position reads "All channels · n of m". At cold launch the current group is the catalogue's `sourceGroup(of:)`.
- Number entry: digits beyond the longest channel number in the catalogue's index (never fewer than four) are ignored. Matching uses the catalogue's index. "No channel n" lasts one second ±100 ms on the injected clock.
- Select while the bar or box shows is consumed. The bar hides before the overlay opens, and select in the box tunes.
- Remaining text and progress refresh each minute.
- The bar and box never take focus. `Channel.streamURL` is never shown, logged or used in an identifier (adr-0003).
- `TV-ZapBar.dc.html` is a composite. The box and bar are never on screen together, and the state boards are authoritative. The 132 by 88 identity tile uses radius 12, above the logo-tile range. Digit entry is narrowed to hardware keyboards per section 2 of the design system.
- Digit handling lives in a model with injected key events and clock, since XCUITest cannot type into a non-text view on tvOS.
- Play/pause, swiping and Menu tests run as UI tests; formatting rules run as core tests.

## Risks / Trade-offs

- [The quality badges depend on the playback engine change] → tested against a fake engine until it lands.
- Open question: should the five-second delay be a setting? If it syncs, it needs a settings field and a decision record under adr-0002. Can be decided during implementation.
