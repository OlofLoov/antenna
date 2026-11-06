## Why

Guide data arrives as XMLTV files that are routinely 20 to 100 MB, and holding one as a DOM on an Apple TV is not an option. The app needs programmes and channel names read in one event-driven pass, tolerant of the timestamp forms providers use and strict about dropping entries it cannot place on a timeline. This serves the viewer who wants "to see what is on now and next without leaving the picture" and "a guide grid of what is on across channels over the coming days".

Written after the fact. It records behavior shipped in commit 082034b so later changes have a spec to revise.

## What Changes

- Read each `<channel id>` with its first `<display-name>`.
- Read each `<programme channel start stop>` with `title`, `sub-title`, `desc`, `category` and `icon src`.
- Read timestamps `yyyyMMddHHmmss ±HHMM`, with or without a space before the offset, and `yyyyMMddHHmmss` as UTC.
- Parse event by event from data in memory, building no DOM.
- Read stray ampersands and HTML named entities as text.

Out of scope:
- Downloading or decompressing the file.
- Matching programmes to channels, storing or caching them.
- Choosing a language among several `<title lang>` elements.
- `episode-num`, `credits`, `rating`, `date`, several categories and channel icons.
- Recovering a partial guide from a document with other well-formedness errors.
- Parsing from a file or stream, delivering programmes incrementally, and cancelling a parse.

## Capabilities

### New Capabilities
- `xmltv-guide-parsing`: read an XMLTV document into channel names and programmes.

### Modified Capabilities

## Impact

- AntennaCore: `XMLTVParser`, `Programme`, `XMLTVError`.
- No caller outside tests until the `guide-data` capability.
