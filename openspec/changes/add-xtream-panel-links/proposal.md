# Proposal

## Why

> As a viewer whose provider sent me one playlist link, I want Movies, Series and the guide, the way TiviMate and IPTV Smarters show them for the same link.

Most provider playlist links are Xtream panels: `http://host:port/get.php?username=U&password=P&type=m3u_plus&output=ts`. Added as an M3U playlist, such a link gives live channels only. Antenna shows Movies and Series for Xtream logins alone, and a playlist that names no guide in its header gets no guide. On a real device test the user added such a link and got neither, while other players showed both for the same link.

After this change the app sees that the link is an Xtream login, offers to add it as one with the server, username and password filled in, and an existing playlist source can switch to Xtream in place. A playlist kept as M3U still gets the panel's guide.

## What Changes

- Recognize an Xtream panel playlist link: a `get.php` link with a username and password. The server is the link's scheme, host, port and any path before `get.php`.
- The add form, in onboarding and in Settings, shows "This link is an Xtream login. Add it as Xtream to get Movies, Series and the guide." under a playlist link that is one, with a button that switches the form to Xtream with the fields filled in.
- A playlist source whose link is a panel link shows the same offer in its details. Switching checks the login with the panel, then turns the source into an Xtream login with the same name, place in the list and guide link. Favorites and own-group channels move to the Xtream channel ids. The login moves from the synced link to the Keychain.
- A panel playlist with no guide link entered and none in its header uses the panel's guide.

Out of scope:
- Movies and series from playlists that are not Xtream panels (a later change).
- Switching an Xtream source back to a playlist.
- Moving Recents, the Apple TV's last channel, language picks and hand-picked guide matches to the new ids.
- Recognizing panels that use another script name than `get.php`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `source-management`: panel links are recognized, the add form offers Xtream for one, and a playlist source can switch to Xtream.
- `guide-data`: a panel playlist without a guide link falls back to the panel's guide.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS.
- Depends on: `xtream-live-source` (channel ids and the guide link), `fix-m3u-channel-ids` (the favorites rewrite this reuses), `add-guide-sources-and-channel-mapping` (the provider guide entry).
- Data: no schema change. A switched `SourceRecord` changes its kind, link and credential key in place.
- Blocked on: nothing.
