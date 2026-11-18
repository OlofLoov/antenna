# Proposal

## Why

A movie and series watcher binging a show on the couch or in bed reaches the end of an episode and lands back on the series page. To see the next one they pick it from the list or press Play, every 40 minutes. Netflix, Apple TV and Disney+ offer the next episode near the end and play it on their own after a short countdown. The owner approved the same for Antenna on 2026-11-18.

Afterwards, near the end of an episode the viewer can jump straight to the next one, or let a 10-second countdown start it in the same player. They can cancel and watch the credits instead. After three episodes in a row with nobody touching the remote, the app asks "Still watching?" instead of playing on. Anyone who does not want this can turn it off in Settings on that device.

## What Changes

- From 30 seconds before the end of an episode, a small Next episode button sits in the bottom right corner over the playing picture. It does not pause or cover the picture. Pressing it plays the next episode.
- From 15 seconds before the end, an Up next card takes its place: the next episode's picture when the provider sends one, "S2 E5 · Title", "Next episode in 10" counting down, Play now and Cancel. At zero, or on Play now, the next episode plays in the same player.
- An episode shorter than 5 minutes, or one whose length the stream does not give, shows the card with its countdown when it ends instead.
- Moving back out of the last 30 seconds hides the button and the card. Cancel hides them for the rest of the episode, which plays to its end and then goes back to the series page.
- "Next" is the episode after this one in the season picker's order, from the last episode of a season to the first of the next season. Specials and episodes with no season only lead to the next episode in the same group. After the last episode, or when the episode list cannot load, the episode ends as it does today.
- After three episodes in a row started by the countdown with no press, tap or key from the viewer, the card asks "Still watching?" with Keep watching and Cancel, and does not count down. At the end the picture stops and the question stays until answered.
- The finished episode counts as watched as soon as the next one starts, so Continue watching and the series page's UP NEXT move on.
- Coming back to the series page brings the last episode that played into view, not the one the viewer first picked.
- An episode that ends goes back to the series page, as the spec already says. Today the player stays on the last frame.
- Settings gets "Autoplay next episode", on by default, kept on each device.
- Apple TV: the button and the card take focus when the viewer swipes down to them. Left and right clicks still skip 10 seconds, play/pause still pauses, and Back on the card cancels it. The remote hints name the new actions.

Out of scope:
- Skipping intros or credits by markers. Providers send none.
- Autoplay for movies (no "next movie"), live TV and catch-up.
- Playing the next episode from Picture in Picture.
- Syncing the setting across devices.

## Capabilities

### New Capabilities

- `up-next`: the Next episode button, the Up next card and its countdown, which episode is next, Cancel, "Still watching?", progress after an autoplay, and the setting.

### Modified Capabilities

- `title-detail-and-episode-picker`: "Play an episode and come back" ends on the series page and brings the last episode played into view.
- `control-hints`: "Each screen lists its own actions" covers the Next episode button and the Up next card.

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV.
- Depends on `player-controls-and-playback-errors/move-around-in-a-movie-or-episode` (the transport whose clicks stay live under the card), `title-detail-and-episode-picker/play-starts-the-right-episode` (the order next follows), `movies-and-series-browsing/your-place-is-saved-as-you-watch` and `control-hints/each-screen-lists-its-own-actions`.
- AntennaCore gains the rules: when the button and the card show, which episode is next, the countdown and the run of episodes without input.
- No new synced data and no schema change. The setting is one UserDefaults key.
- Blocked on nothing.
