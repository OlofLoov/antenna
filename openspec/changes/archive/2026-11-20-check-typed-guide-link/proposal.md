# Proposal

## Why

> As a household setter-upper typing a guide link from my provider's email, when I paste the wrong one, I want to hear right away that it opens a login page or a 404, not find a failed row in the list later.

Today Save accepts any `http` or `https` link that is not already listed. A link to the provider's portal, a playlist link pasted into the guide field, or a typo that answers 404 is saved, and the user learns about it only when the row says "Could not download". The fix is to read the first bytes before saving and refuse the link when the answer is plainly not a guide.

## What Changes

- Saving a typed guide link, in Add guide URL and in Re-enter link, first reads the start of the link: at most 4 KB, for at most 5 seconds.
- The link is refused with a message under the field when the server answers 404 or 410, 401 or 403, an HTML page, or a body that is neither XMLTV nor gzip.
- In every other case the link is saved as today: it looks like a guide, the device is offline, the server is slow or answers 5xx or 429, or the first bytes cannot decide. The offline scenario keeps its retry line.
- While the check runs, Save reads "Checking…" and cannot be pressed again. Cancel stops the check and saves nothing.

Out of scope:
- Counting channels or programmes before saving, or downloading the whole guide.
- Checking guides named by the playlist or the Xtream login, which the user did not type.
- New screens or rows.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `guide-sources-and-channel-mapping`: Add a guide link refuses a link that is plainly not a guide and saves one it cannot decide on.

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV share the form.
- Code: a link check in `Packages/AntennaCore/Sources/AntennaCore/GuideMapping/`, the model and the form in `Apps/Shared/Views/Settings/GuideSources/`, and a stub for the Guide sources UI-test run in `Apps/Shared/Debug/`.
- Strings: four refusal messages in sv, de, es, fr, pt-BR and ar. "Checking…" is already translated.
- Depends on: the guide download session settings and the `guide-sources-and-channel-mapping` add form.
