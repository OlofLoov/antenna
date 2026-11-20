# Design

## Context

Boards: `iPhone-GuideSources`, `iPad-GuideSources` and `TV-GuideSources`
draw the Add guide URL form: one field, the error line under it, the
Keychain footer and Save. The refusal uses that error line and Save keeps
its place, so no board changes. Design-system requirements followed: forms
use the platform form style, and the type scale. Not drawn: Save's
"Checking…" label, which is the button's own text.

The form is one view, `GuideAddLinkSheet`, on every platform, so iPhone,
iPad, Mac and Apple TV get the check from the same code. Re-enter link
opens the same form with `replacing` set.

## Goals / Non-Goals

Goals:
- Refuse a typed link that is plainly not a guide, before it is saved.
- Never refuse a link because the network or the server is having a bad
  moment.

Non-goals:
- Coverage counts, a full download, or a new screen.
- Checking guide links the playlist or the Xtream login supply.

## Decisions

### 1. What refuses and what saves

| Answer | Result |
| --- | --- |
| 404, 410 | Refused: "The server has nothing at this link." |
| 401, 403 | Refused: "The server refused this link. Check its login or token." |
| 2xx starting `<!DOCTYPE html` or `<html` | Refused: "This link opens a web page, not a guide." |
| 2xx starting with anything else that is not a guide | Refused: "This link is not an XMLTV guide." |
| 2xx starting with gzip's `1f 8b`, `<?xml`, `<tv` or `<!DOCTYPE tv` | Saved |
| Empty or blank 2xx body, a leading `<!--`, a body cut off mid-marker | Saved |
| Any other status (5xx, 429, 3xx left over) | Saved |
| Offline, unknown host, timeout, any transport error | Saved |

The body is read after a UTF-8 byte order mark and leading whitespace, as
`GuideDecoder.sniff` does. The decoder accepts any `<`; the check is
stricter because a guide download that turns out to be HTML fails later
anyway, and an XMLTV file starts with the XML declaration, a doctype or
`<tv`. A leading comment is rare but legal, so it saves.

An empty 200 is saved: some providers build the guide on first request,
and the row reports "No programmes in the guide" if it stays empty.

Options considered: refusing on any download error (rejected, a provider's
bad minute would block a good link); a HEAD request (rejected, many IPTV
panels answer HEAD with 405 or a different status than GET); checking
`Content-Type` (rejected, panels send `text/html` for XMLTV often enough).

### 2. How the bytes are read

`GuideLinkProbe` in AntennaCore holds a `Fetch` closure,
`(URL) async throws -> (status: Int, head: Data)`, and a timeout. The live
fetch uses `URLSession.bytes(for:)` on a session with the guide download
configuration (ephemeral, no cache, no cookies) and a 5 second request
timeout, reads at most 4096 bytes and cancels the task. `check(_:)` races
the fetch against `timeout` (5 seconds) in a task group, so a server that
never answers gives `.uncertain` on time. The verdict is
`.guide`, `.uncertain` or `.refused(GuideLinkInput.Problem)`; the four new
`Problem` cases are `notFound`, `unauthorized`, `webPage` and `notGuide`.

The probe sends the link as typed, login included, to the server that link
names, as the download will. It logs nothing.

### 3. Where it runs

`GuideSourcesModel.add` checks the typed text as today, then runs the
probe, and saves only when the verdict is not `.refused`. The model takes
the probe in its initializer; the app passes `GuideLinkProbe.app`, which in
a Debug build under `-ui-testing-guide-sources` answers `guide-sources.web`
with an HTML page and fails every other host as unknown. Unknown is
uncertain, so the existing UI test's `guide-sources.invalid` link still
saves.

The form keeps its `saving` flag, which already disables Save, and shows
"Checking…" as Save's label while it is set. Cancel cancels the save task;
`add` saves nothing when its task was cancelled during the check.
