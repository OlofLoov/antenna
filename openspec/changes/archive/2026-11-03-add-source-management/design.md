## Context

No board. The shipped UI predates the design boards; the boarded Settings is `add-sources-and-settings`, the add flow `add-first-run-onboarding`, and Live `add-live-tv-on-iphone-ipad-mac`. No design-system requirement applies. Follows decision adr-0001 (hardware playback path for MPEG-TS), decision adr-0002 (SwiftData with private CloudKit for sync), decision adr-0003 (credentials in iCloud Keychain) and decision adr-0005 (AntennaCore is UI-free). Runs on iOS, iPadOS, macOS and tvOS.

Accessibility identifiers: `settings.addSource`, `settings.source.<id>`, `addSource.save`, `addSource.error`, `channels.emptyState`, `player.view`.

## Goals / Non-Goals

**Goals:**
- One store of sources, synced, with secrets only in the Keychain.
- One combined channel list in source sort order.

**Non-Goals:**
- Rendering load errors, editing sources, a delete affordance on tvOS and macOS.

## Decisions

- `AddSourceView.save()` and the Settings delete body moved into a testable type with an injected `CredentialStore`. `SourceLoader` takes an injected `URLSession` and `CredentialStore`, and `ChannelListModel` calls it through that seam.
- Keychain items use service `se.codecrave.antenna.sources`, account `SourceRecord.id.uuidString`, synchronizable.
- Sources load one after another; the list waits for the slowest. A list with channels does not reload on appearance; a load that yields zero channels leaves the list on the loading indicator and retries on each appearance.
- An unknown kind from a newer app version falls back to M3U. A record with no URL, possible after a partial sync, is skipped by the loader.
- The playlist is decoded as UTF-8 with replacement characters.
- Every stored property on `SourceRecord` is optional or defaulted, with no unique attributes (decision adr-0002). Adding the same source twice is allowed.
- The player screen uses `AVPlayer` for every URL as a stopgap, against decision adr-0001, until a playback change replaces it.

## Risks / Trade-offs

- On tvOS synchronizable Keychain items do not arrive, so a synced Xtream or Stalker source adds no channels there.
- A Keychain item that arrives after its record changes nothing the list watches, so that source stays empty until another reload or a relaunch.
- User-supplied M3U URLs with embedded credentials are stored, synced and shown in clear in Settings.
- The Keychain failure message shows the raw status, such as "unexpectedStatus(-34018)".
- All channels sit in one array and one list with an image per row; memory and scrolling are not bounded.
- Not signed into iCloud, nothing syncs and nothing tells the user. A failure to create the model container stops the app at launch.
- Deleting a source leaves its favorites behind.
- Open question: should the Stalker option stay hidden until the portal handshake ships?
- Open question: where is the recorded load error rendered, inline per source in Settings or as a banner in the channel list?
- Open question: should credential-bearing M3U URLs be redacted in Settings, or split into a Keychain item plus a base URL?
- Open question: sort-order collisions when two devices add a source at once.
