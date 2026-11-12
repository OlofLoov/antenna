# Proposal

## Why

Subtitles start off on every channel today, even when the sound is in a language the viewer does not speak, and the only way to turn them on is to open Audio & Subtitles and pick a row. The engine already chooses tracks by preferred languages, but the app never passes the subtitle languages, so that choice never happens.

Who it is for:
- The movie and series watcher who watches a Swedish drama with English as their language: "Turn on English subtitles when I don't understand the sound, and leave them off when I do."
- Someone who always reads along, hard of hearing or learning a language: "Subtitles on, every time, in my language."
- The living-room viewer: "One press to turn subtitles on or off, without hunting through a list."
- The sports fan with a European provider whose raw TS channels carry DVB subtitles: "Show the broadcaster's subtitles like any other track."

Afterwards a stream starts with subtitles the way Apple's own "Auto" setting does, a Subtitles setting picks Off, Auto or Always, and the player has a one-step subtitles switch on every platform.

## What Changes

- The starting subtitle follows the device's languages. Auto: sound in one of the user's languages starts with subtitles off; other sound starts with subtitles in the user's first language the stream has. Forced subtitles in the user's language always show.
- A "Subtitles" preference with Off, Auto and Always, Auto by default, synced with the other preferences. Always starts the user's first matching language whenever the stream has it.
- A language picked on a channel still wins over the setting when the user comes back to that channel.
- Movies and episodes start by the same rule.
- Forced subtitle tracks are reported by both engines and named "Forced" in the lists.
- A subtitles on/off button in the player: next to Audio & Subtitles on iPhone, iPad and Mac, and in the info panel on Apple TV.
- DVB picture subtitles in raw MPEG-TS on the FFmpeg path: the LGPL build gains FFmpeg's `dvbsub` decoder, the bitmaps are drawn over the picture on every platform, and they join the same track list and language rule. This ships as its own later slice.

Out of scope:
- Downloading subtitles from a subtitle service or a file: subtitles come only from the stream.
- A timing offset for subtitles.
- Teletext subtitles in raw TS: they need a teletext page decoder and page numbers per channel, which no provider lists, and FFmpeg's teletext decoder needs libzvbi, a separate library we would have to ship and keep LGPL.
- Subtitle styling (size, color, background).
- Closed captions carried inside the video (CEA-608/708).

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `playback-engine`: adds how the starting subtitle is chosen from the setting and the device's languages, forced subtitles, and DVB picture subtitles. Extends "Audio and subtitle languages" from change `add-playback-engine`.
- `player-controls-and-playback-errors`: adds the one-step subtitles switch next to "Choose audio and subtitles" from change `add-player-controls-and-playback-errors`.
- `sources-and-settings`: adds the Subtitles preference next to "Choose how the app behaves" from change `add-sources-and-settings`.

## Impact

- AntennaCore: the starting-track rule, a subtitle mode, a forced flag on tracks, the preference value.
- Apps: the synced preferences record gains one defaulted field; the live, shell, multi-view and movie players pass the subtitle languages and mode; the player controls and the Apple TV panel gain the switch; Settings gains a row.
- AntennaDemux and the FFmpeg build: the `dvbsub` decoder, picture cues, a new FFmpeg release tag and package checksum.
- Boards: `iPad-Player`, `iPhone-Settings`, `TV-Settings-Preferences` change; `iPhone-FullScreen-Subtitles` and `TV-Player-Subtitles` are new.
- Depends on change `add-playback-engine`, change `add-player-controls-and-playback-errors`, change `add-sources-and-settings` and change `add-live-tv-on-iphone-ipad-mac`. Nothing blocks it.
