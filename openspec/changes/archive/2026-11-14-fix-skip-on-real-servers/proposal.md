# Proposal

## Why

> Series or movies said it was unable to skip?

The owner, on a real Apple TV and iPhone, after the movie transport landed. Skipping in a movie or episode showed "This stream can't skip" on titles whose server can skip. A movie and series watcher should be able to skip in every film the server can jump in, and when a server really cannot, the player should say so before they press anything.

## What Changes

- A film on the FFmpeg path (Matroska, AVI, MPEG-TS) asks for its first bytes as a range. A server that answers with part of the file can skip, even when it never says it accepts ranges and sends no length on a plain request.
- A skip pressed while the previous skip is still reopening the film moves the film instead of being refused.
- When a skip reopens the connection, the old one closes before the new one opens, so a provider that allows one connection per account does not refuse it.
- Apple's player no longer refuses a skip in a ready film only because the ranges it can skip to are briefly empty.
- When the player knows a film's server cannot skip, the controls say "This stream can't skip" whenever they show, and skips and drags do nothing.

Out of scope:
- Servers that refuse every range. Their films still cannot skip; they now say so up front.
- Live TV and timeshift, which keep their own controls.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `playback-engine`: "Films start where you left off, skip, and end" covers servers that skip without saying so, redirects, and a skip during a skip.
- `player-controls-and-playback-errors`: "Move around in a movie or episode" says the can't-skip line shows before a press.

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV, both playback paths.
- Depends on `add-title-transport-controls` (archived) and PR #367, which wires the title details call so a movie's container extension reaches the player again.
- The test fixture server gains a server that takes ranges without saying so, and a redirect.
