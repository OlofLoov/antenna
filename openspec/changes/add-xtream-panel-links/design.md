# Design

## Context

An Xtream panel serves its live, movie and series lists as one M3U file at `get.php?username=U&password=P&type=m3u_plus&output=ts`. Providers hand that link out as "your M3U link", so users add it as a playlist. The app then:

- shows Movies and Series only when a source is `.xtream` (`ShelfModel.hasXtream`, read by `RootView`);
- finds a playlist's guide only in the playlist header or the link the user typed (`GuideList.resolve`, `GuideURLResolver`);
- keeps the whole link, login included, in `SourceRecord.url`, which syncs through CloudKit. An Xtream source keeps only the server there and the login in the Keychain.

Clipboard Fill in already turns a copied link with `username` and `password` into Xtream fields (`CopiedLink`), but a link typed or pasted into the Playlist field is taken as it is.

Channel ids differ by kind. An M3U channel's id is `m3u.<hash>` of its guide id, name and group (`fix-m3u-channel-ids`). An Xtream channel's id is `xtream#<host>#<stream_id>` (`XtreamTitleID`). A panel's M3U entry links to `<server>/live/U/P/<stream_id>.ts` or `<server>/U/P/<stream_id>`, so the stream id, and with it the Xtream id, can be read from the link of each loaded channel.

## Goals / Non-Goals

**Goals:**
- A panel link added as a playlist gets the offer to be added as Xtream, with nothing to retype.
- An existing panel playlist can become an Xtream source without losing its name, place, favorites or own-group channels.
- A panel playlist the user keeps as M3U gets the panel's guide.

**Non-Goals:**
- Movies and series from a panel playlist kept as M3U, or from other playlists. A later change classifies playlist entries.
- Moving Recents, the Apple TV's last channel, language picks and hand-picked guide matches across the switch.
- Switching back from Xtream to a playlist.

## Decisions

### Recognizing a panel link

`XtreamPanelLink` in AntennaCore (`Xtream/XtreamPanelLink.swift`) parses a `URL` or text. It needs `http` or `https`, a host, a last path part equal to `get.php` (case-insensitive), and non-empty `username` and `password` query items. `server` keeps scheme, host, port and the path before `get.php`, with no trailing slash, query or fragment. It exposes `credentials: XtreamCredentials`, `fields` for the add form, and `liveChannelIDs(for:)`.

Options considered:
1. **Any link with `username` and `password` in the query**, as `CopiedLink` does. Catches `xmltv.php` and `player_api.php` links and unrelated sites that use those names. Too loose for an offer that changes the source kind.
2. **`get.php` plus both query items** (chosen). It is the script name every Xtream Codes panel and its clones serve the playlist from.
3. **Ask the server** (`player_api.php`) whenever a playlist is added. One more request per add, and it says nothing a link check cannot.

`CopiedLink` is left as it is: Fill in already offers Xtream, and changing what it keeps of the path is a separate fix.

### The offer in the add form

`OnboardingForm.Phone` and `.Television` show an `XtreamLinkOffer` banner under the Playlist group while `XtreamPanelLink(fields.url)` is non-nil. The banner sits in the same place and style as the clipboard banner: accent-tinted, an icon, the sentence and a "Use Xtream" button. The form gets the decision as a value in `Status` (`xtreamLink: Bool`) and the action as a closure (`useXtream`), so the component stays free of parsing. `OnboardingModel.useXtream()` calls `SourceFields.useXtream()` in AntennaCore, which sets the kind, server, username and password and keeps the name and guide link.

Options considered: switch the type silently as the link is typed (surprising, and a user who wants the playlist could not keep it); refuse Connect for a panel link (blocks users whose panel rejects `player_api.php`); a banner with a button (chosen).

### Switching an existing playlist

Options considered:
1. **Switch in place** (chosen). The `SourceRecord` keeps its `id`, `name`, `sortOrder`, `createdAt` and `epgURL`; `kindRaw` becomes `xtream`, `url` becomes the server, and `credentialKey` names a new Keychain item holding the login. Favorites, own-group channels, guide settings and hand-picked matches are keyed by source id and stay attached. The login leaves the synced record.
2. **Add a new Xtream source and offer to delete the playlist.** Two steps for the user, a second source in every list until they delete the first, and favorites stay on the deleted source unless they are copied, which needs the same id map as option 1.
3. **Keep the playlist and add the Xtream source beside it for Movies and Series only.** Doubles the live channels and leaves the login in CloudKit.

Steps in `SourceEditor.switchToXtream(channels:in:)`:
1. Parse the saved link (the field as it stands, so an edited link counts).
2. Refuse when another Xtream source has the same server key and username in this device's Keychain: "This source is already added."
3. Check the login with `connector.probe(.xtream, …)`. A failure shows the connect message and changes nothing.
4. Save the login under `record.credentialKey ?? record.id.uuidString`.
5. Build the id map with `XtreamPanelLink.liveChannelIDs(for:)` from the source's loaded channels, which the details screen reads from `\.loadedChannels`.
6. Change the record, rewrite ids with `ChannelIDMigration.rewrite(_:source:in:)`, save once.

The details screen then makes a new `SourceEditor` for the Xtream descriptor and asks the refresher to load the source. Live sees a changed descriptor and reloads it as Xtream; the shelves appear because `ShelfModel` now finds an Xtream source.

### The id map

`liveChannelIDs(for:)` maps each channel whose stream link is on the same host and has the path `[live/]U/P/<digits>[.ext]` under the server path to `XtreamTitleID(host:kind:.live, rawID:)`. Movie and series entries (`/movie/`, `/series/`) and links to other hosts map to nothing, so their favorites stay with the old id and show as missing. The login in the link is not compared: a panel that rotates passwords still maps.

`ChannelIDMigration.rewrite` is the existing favorite and member rewrite with the `://` filter lifted: it rewrites every favorite of the source (or with no source) and every member of the source whose id the map names, and deletes a rewritten record that duplicates one already saved. `apply` keeps its filter and calls the same code.

Options considered for when to rewrite: at the switch with the channels in memory (chosen); on the first Xtream load, by keeping the map until then (needs somewhere to keep it, and the old channels are gone by then); not at all (every favorite of the source lost).

### The panel guide for a playlist

`GuideList.resolve` gains `panelGuide: URL?` (default nil). For `.m3u` with a panel guide it adds the `.provider` entry with that link, turned on only when no saved link and no playlist links exist. `GuideEngine.guideList` passes `GuideURLResolver.panelGuide(kind:url:)`. `GuideEngine.loadGuide` fetches a playlist's `.provider` entry from its link with `loginURL: true`, so logs redact it as they do the Xtream guide. `GuideURLResolver.resolve` falls back to the same link for `.m3u`, which the onboarding checklist uses to decide whether a guide line shows, and `SourceRefresher` counts it as a guide.

The provider entry rather than a playlist entry: the Guide sources screen already labels it "Provider guide", lets the user turn it off, and does not offer to delete it.

### Secrets

The login is read from the link in memory, saved with `CredentialStore` (synchronizable Keychain) and never logged. `XtreamPanelLink`'s `description`, `debugDescription` and mirror show the host only, as `XtreamCredentials` does. After a switch the synced record holds the server only. A panel playlist kept as M3U still holds the login in its link, as it did before this change.

### Boards

- `iPhone-Onboard-2-XtreamLink` (new): the playlist form with the offer, which also stands for the iPad and Mac sheet.
- `TV-Onboard-3-XtreamLink` (new): the Apple TV form with the offer under the Guide URL field.
- `iPhone-Settings-Detail-XtreamLink` (new): a playlist's details with the "Use Xtream" section, which also stands for `iPad-Settings` and `TV-Settings`, since the details are the same SwiftUI `Form` on each.
- Followed as they are: `iPhone-Onboard-2-M3U`, `TV-Onboard-3-M3U`, `iPhone-Settings-Detail`.

Design-system requirements followed: every screen has a board, visual changes update the boards, accessibility identifiers follow the board. Identifiers: `onboarding.xtreamOffer`, `onboarding.useXtream`, `settings.details.xtreamOffer`, `settings.details.useXtream`.

Not drawn: the details while the switch checks the login, which shows "Checking…" in the button's text style, as Save does.

## Risks / Trade-offs

- [A favorite of a channel that was not loaded when the user switched] → stays with its M3U id and shows as missing. The offer is in the details, which open from Settings after the channels have loaded in the same run.
- [Recents and the Apple TV's last channel] → keep M3U ids and stop matching, as after a channel rename. They refill as the user watches.
- [Hand-picked guide matches keyed by the M3U channel id] → stop applying; the Xtream channel carries the panel's guide id, which usually matches without a pick.
- [A device still on an earlier version] → sees an Xtream source and loads it like any other, once the Keychain item syncs.
- [A panel that serves `get.php` but rejects `player_api.php`] → the switch fails with the connect message, and the playlist keeps working.
