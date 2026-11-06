## Purpose

Reads an XMLTV guide file of 20 to 100 MB in one event-driven pass into channel names and a flat list of programmes, tolerant of the timestamp forms providers use and strict about entries it cannot place on a timeline. It serves the viewer who wants "to see what is on now and next without leaving the picture" and "a guide grid of what is on across channels over the coming days".

## ADDED Requirements

### Requirement: Channel display names
The system SHALL name each `<channel>` by its first `<display-name>`, keyed by the channel's `id` attribute.

#### Scenario: Two display names
- **GIVEN** `<channel id="a"><display-name>A HD</display-name><display-name>A</display-name></channel>`
- **WHEN** the guide is parsed
- **THEN** channel "a" is named "A HD"

#### Scenario: Channel without an id or a display name
- **GIVEN** a `<channel>` without an `id` attribute, and another without any `<display-name>`
- **WHEN** the guide is parsed
- **THEN** neither has a name in the result

#### Scenario: Two channels share an id
- **GIVEN** two `<channel>` elements with the same `id`
- **WHEN** the guide is parsed
- **THEN** the first display name across both wins

### Requirement: Empty first display-name wins
The system SHALL keep the first `<display-name>` even when it is empty.

#### Scenario: Empty first display name
- **GIVEN** `<channel id="a"><display-name></display-name><display-name>A</display-name></channel>`
- **WHEN** the guide is parsed
- **THEN** channel "a" is named ""

### Requirement: Programme fields
The system SHALL read each programme's channel, start, stop, `title`, `sub-title`, `desc`, `category` and `icon src`, trimming whitespace and newlines from text.

#### Scenario: Sample guide
- **GIVEN** the first programme of the sample guide fixture
- **WHEN** the guide is parsed
- **THEN** it is on channel "SkySportsF1.uk" from 2026-11-03T18:00:00Z to 20:00:00Z, titled "Grand Prix Live", subtitle "São Paulo", summary "Lights out.", category "Sport", icon `http://img/gp.jpg`

#### Scenario: Nested markup in text
- **GIVEN** a description `A <b>bold</b> c`
- **WHEN** the guide is parsed
- **THEN** the summary is "A bold c"

#### Scenario: Several icons
- **GIVEN** a programme with several `<icon>` elements, or one whose `src` is not a valid URL
- **WHEN** the guide is parsed
- **THEN** the last `src` wins, and an invalid one gives no icon

#### Scenario: Missing title, empty channel or unknown channel
- **GIVEN** a programme with no `<title>`, one with `channel=""`, and one whose channel has no `<channel>` element
- **WHEN** the guide is parsed
- **THEN** all three are kept, the first with an empty title and the second with an empty channel id, and attribute values are not trimmed

### Requirement: Absent optional fields are nil
The system SHALL leave subtitle, summary, category and icon empty when the programme does not carry them.

#### Scenario: Title only
- **GIVEN** a programme whose only child is `<title>T</title>`
- **WHEN** the guide is parsed
- **THEN** subtitle, summary, category and icon are absent

### Requirement: Whitespace-only text is nil
The system SHALL treat a text element holding only whitespace as absent.

#### Scenario: Blank description
- **GIVEN** a programme with `<title>T</title><desc>  </desc>`
- **WHEN** the guide is parsed
- **THEN** the summary is absent

### Requirement: Timestamp with zone offset
The system SHALL apply a `±HHMM` or `±HH:MM` offset after the 14 timestamp digits, with or without spaces before it, when its hours are at most 14. Any other suffix SHALL be ignored and the first 14 characters read as UTC.

#### Scenario: Positive and negative offsets
- **GIVEN** a programme with `start="20261103200000 +0100" stop="20261103210000 +0100"`, or the same with no space, or `-0530`
- **WHEN** the guide is parsed
- **THEN** the start is 2026-11-03T19:00:00Z for both `+0100` forms and 2026-11-04T01:30:00Z for `-0530`, and the stop is one hour later

#### Scenario: Unrecognized suffix
- **GIVEN** a timestamp ending in `UTC`, `+1` or `+9900`
- **WHEN** the guide is parsed
- **THEN** the suffix is ignored and the first 14 characters are read as UTC

### Requirement: Negative zone offset
The system SHALL subtract a negative offset to reach UTC.

#### Scenario: Minus five hours
- **GIVEN** a programme with `start="20261103200000 -0500" stop="20261103210000 -0500"`
- **WHEN** the guide is parsed
- **THEN** it runs from 2026-11-04T01:00:00Z to 02:00:00Z

### Requirement: Timestamp without zone is UTC
The system SHALL read a timestamp with no offset as UTC.

#### Scenario: No offset
- **GIVEN** a programme with `start="20261103200000" stop="20261103210000"`
- **WHEN** the guide is parsed
- **THEN** it runs from 2026-11-03T20:00:00Z to 21:00:00Z

### Requirement: Invalid intervals are dropped
The system SHALL drop a programme whose stop is not after its start, or that lacks a parseable start, a parseable stop or a channel attribute, and SHALL keep parsing the programmes after it.

#### Scenario: Each invalid case
- **GIVEN** a programme titled "Bad" whose stop is before its start, equal to its start, missing, or whose start is missing or reads `2026XX03200000`, or which has no `channel`, followed by a valid programme titled "Good"
- **WHEN** the guide is parsed
- **THEN** the only programme returned is "Good"

#### Scenario: Timestamp without seconds
- **GIVEN** a timestamp in the form `yyyyMMddHHmm`
- **WHEN** the guide is parsed
- **THEN** the programme is dropped

### Requirement: Malformed XML throws a typed error
The system SHALL report a document that is not well-formed as a malformed-guide error carrying the line and column where reading stopped, discarding every programme already read. No lower-level parser error SHALL reach the caller.

#### Scenario: Unclosed programme
- **GIVEN** the four lines `<tv>`, `<programme channel="a" start="20261103200000" stop="20261103210000">`, `<title>T</title>`, `</tv>`
- **WHEN** the guide is parsed
- **THEN** it fails as malformed at line 4, column 6

#### Scenario: Bare less-than sign
- **GIVEN** a bare `<` in text anywhere in the document
- **WHEN** the guide is parsed
- **THEN** it fails as malformed and no programmes are returned

#### Scenario: Well-formed but not XMLTV
- **GIVEN** `<tv/>` or a well-formed XHTML page
- **WHEN** the guide is parsed
- **THEN** it returns no channels and no programmes, without an error

### Requirement: Non-XML data throws
The system SHALL report data that is not XML as a malformed guide.

#### Scenario: Empty or compressed bytes
- **GIVEN** empty data, or gzip bytes passed without decompression
- **WHEN** the guide is parsed
- **THEN** it fails as malformed

### Requirement: First repeated title wins
The system SHALL keep the first of several elements of the same kind in a programme.

#### Scenario: Two languages
- **GIVEN** a programme with `<title lang="en">A</title><title lang="sv">B</title>`
- **WHEN** the guide is parsed
- **THEN** the title is "A"

### Requirement: Empty first element is skipped
The system SHALL skip an empty first `title`, `sub-title`, `desc` or `category` in favor of a later non-empty one.

#### Scenario: Empty then filled
- **GIVEN** a programme with `<title></title><title>T</title>`, `<sub-title> </sub-title><sub-title>S</sub-title>`, `<desc></desc><desc>D</desc>` and `<category/><category>C</category>`
- **WHEN** the guide is parsed
- **THEN** title, subtitle, summary and category are "T", "S", "D" and "C"

### Requirement: Channel icons are not attributed to programmes
The system SHALL NOT give a programme the icon of a `<channel>` element.

#### Scenario: Channel icon then a programme without one
- **GIVEN** a `<channel>` containing `<icon src>`, followed by a programme without an icon
- **WHEN** the guide is parsed
- **THEN** the programme has no icon

### Requirement: Airing check
The system SHALL report a programme as airing from its start time inclusive to its stop time exclusive.

#### Scenario: Start, middle and stop
- **GIVEN** a programme from 2026-11-03T20:00:00Z to 21:00:00Z
- **WHEN** asked whether it airs at 20:00Z, 20:30Z and 21:00Z
- **THEN** the answers are yes, yes and no

### Requirement: Large documents parse in bounded time
The system SHALL parse a guide of 100,000 programmes across 500 channels in under 20 seconds on macOS. This is a benchmark run on request, not in CI.

#### Scenario: 100,000 programmes
- **GIVEN** a generated document of 100,000 programmes across 500 channels, each with title, description and category
- **WHEN** it is parsed with benchmarks enabled
- **THEN** 100,000 programmes are returned in under 20 seconds

### Requirement: Programmes keep document order
The system SHALL return programmes in document order, keeping duplicates and overlaps.

#### Scenario: Two identical slots
- **GIVEN** two programmes on channel "a", both 20:00 to 21:00, titled "T1" then "T2"
- **WHEN** the guide is parsed
- **THEN** the titles are "T1" then "T2"

### Requirement: CDATA text is read
The system SHALL read text inside CDATA sections as plain text.

#### Scenario: CDATA title and description
- **GIVEN** a programme with `<title><![CDATA[A & B]]></title><desc><![CDATA[D]]></desc>`
- **WHEN** the guide is parsed
- **THEN** the title is "A & B" and the summary is "D"

### Requirement: Stray ampersands and HTML entities are read as text
The system SHALL read an `&` that starts no valid XML reference as a literal ampersand, and the Latin-1 HTML named entities and common punctuation entities as their characters. A document with neither SHALL be parsed byte for byte unchanged, and other well-formedness errors SHALL still fail as malformed.

#### Scenario: Text a browser would show
- **GIVEN** a programme titled `Tom & Jerry`, `A&nbsp;B`, or containing `&eacute;`, `&copy;` or `&ndash;`
- **WHEN** the guide is parsed
- **THEN** the titles read "Tom & Jerry", "A" then a no-break space then "B", "é", "©" and "–"

#### Scenario: Bare ampersand in an icon link
- **GIVEN** an `icon src` holding a bare `&`
- **WHEN** the guide is parsed
- **THEN** the icon link is read as written

#### Scenario: Entities left alone
- **GIVEN** an unknown name such as `&foo;`, a name without its semicolon such as `&nbsp`, or a reference to a code point XML forbids such as `&#0;`
- **WHEN** the guide is parsed
- **THEN** each is read as literal text, and CDATA, comments, processing instructions and the DOCTYPE are never rewritten

#### Scenario: Documents passed through unchanged
- **GIVEN** a document whose DOCTYPE declares entities, or that starts with a UTF-16 byte order mark, and holds a stray `&`
- **WHEN** the guide is parsed
- **THEN** it is not rewritten and fails as malformed

#### Scenario: Error column after a rewrite
- **GIVEN** an entity rewritten earlier on the same line as a later well-formedness error
- **WHEN** the guide is parsed
- **THEN** the reported column counts the rewritten bytes
