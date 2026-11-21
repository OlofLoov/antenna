## ADDED Requirements

### Requirement: Stream headers from the playlist
The system SHALL read the headers a playlist asks for on a stream from `#EXTVLCOPT:http-user-agent=` and `http-referrer=`, `#EXTHTTP:` with a JSON object, `#KODIPROP:` stream or common headers, the `user-agent` attribute, and a link written as `link|Name=value&Name=value`. The part after `|` SHALL leave the link. Lines between one link and the next SHALL apply to the next, and the `|` part SHALL win over the lines, which win over the attribute. Header values SHALL never be shown or logged.

#### Scenario: VLC options
- **GIVEN** an entry followed by `#EXTVLCOPT:http-user-agent=VLC/3.0.20` and `#EXTVLCOPT:http-referrer=https://site.example/`, then its link
- **WHEN** the playlist is parsed
- **THEN** the channel's stream is asked for with that User-Agent and Referer

#### Scenario: A Kodi link with headers
- **GIVEN** the link `http://s/live/1.ts|User-Agent=VLC/3.0.20&Referer=http%3A%2F%2Fx%2F`
- **WHEN** the playlist is parsed
- **THEN** the stream link is `http://s/live/1.ts`, asked for with User-Agent "VLC/3.0.20" and Referer "http://x/"

#### Scenario: Headers stay with their link
- **GIVEN** an entry with an `#EXTHTTP` line and a following entry with none
- **WHEN** the playlist is parsed
- **THEN** only the first channel has headers

#### Scenario: A header with a line break
- **GIVEN** an `#EXTHTTP` value holding a line break
- **WHEN** the playlist is parsed
- **THEN** that header is left out
