## Why

The XMLTV parser exists and nothing calls it. Nothing downloads a guide, matches programmes to channels, or answers "what is on this channel now", and every live TV screen needs that answer. This change downloads each source's guide, matches it to the user's channels, answers now, next and time-window questions, and tells screens how far a download has got and why it failed. It serves the viewer who wants "to see what is on now and next without leaving the picture" and "a guide grid of what is on across channels over the coming days", and the user who wants several subscriptions "merged into one channel list and one guide".

## What Changes

- Find each source's guide link: the one the user entered, else the playlist's own, else the one an Xtream provider offers for the user's login.
- Download guides one source at a time, gzip included, with progress.
- Match programmes to channels within each source.
- Answer what is on now, what is next, what is on in a time window, and how far ahead the guide reaches.
- Report a guide state per channel: loading, has a guide, no data, unavailable, failed.
- Refresh guides older than 12 hours, and on request.
- Remove a source's guide when the source is deleted.
- Cap guide size so a huge guide cannot exhaust memory.
- Keep logins out of logs and file names.

Out of scope:
- Where the guide is kept between launches (a follow-up decision).
- Syncing the guide through iCloud; each device downloads its own.
- Several guides per playlist, choosing a guide, and matching a channel by hand (`add-guide-sources-and-channel-mapping`).
- Programme artwork and details beyond what the parser reads.
- Reminders, recording and catch-up windows.
- Drawing anything.

## Capabilities

### New Capabilities
- `guide-data`: download, join and query each source's TV guide.

### Modified Capabilities

## Impact

- AntennaCore: `GuideStore` protocol, `GuideIndex`, `GuideURLResolver`, `GuideDecoder`, `GuideFetcher`, `GuideEngine`, redaction.
- App: the `@MainActor` guide store and its wiring to the source loader.
- Depends on `xmltv-guide-parsing`, `xtream-live-source`, `source-management`, `channel-catalogue` and `xtream-vod-client`.
- Follow-up decision needed on where the guide is kept on the device. Until then it lives in memory.
