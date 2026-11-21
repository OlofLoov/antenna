## MODIFIED Requirements

### Requirement: Invalid intervals are dropped
The system SHALL drop a programme whose stop is not after its start, or that lacks a parseable start or a channel attribute, and SHALL keep parsing the programmes after it. A programme with a `stop` that does not parse SHALL be dropped; one with no `stop` attribute SHALL be kept as the programmes-without-a-stop requirement says. A timestamp is parseable only when its first 14 characters are the digits of a real calendar date and time.

#### Scenario: Each invalid case
- **GIVEN** a programme titled "Bad" whose stop is before its start, equal to its start, or reads `2026XX03210000`, or whose start is missing or reads `2026XX03200000`, or which has no `channel`, followed by a valid programme titled "Good"
- **WHEN** the guide is parsed
- **THEN** the only programme returned is "Good"

#### Scenario: Timestamp without seconds
- **GIVEN** a timestamp in the form `yyyyMMddHHmm`
- **WHEN** the guide is parsed
- **THEN** the programme is dropped

#### Scenario: Impossible dates and leading spaces
- **GIVEN** a start of `20261332200000` (month 13), `20261103240000` (hour 24), `20260230200000` (February 30) or ` 20261103200000` with a leading space
- **WHEN** the guide is parsed
- **THEN** the programme is dropped

### Requirement: Stray ampersands and HTML entities are read as text
The system SHALL read an `&` that starts no valid XML reference as a literal ampersand, and the Latin-1 HTML named entities, common punctuation entities and a few others such as `&euro;`, `&trade;` and `&scaron;` as their characters. Entity names SHALL match with their case. A document that needs neither this rewrite nor the Latin-1 one SHALL be parsed byte for byte unchanged, and other well-formedness errors SHALL still fail as malformed.

#### Scenario: Text a browser would show
- **GIVEN** a programme titled `Tom & Jerry`, `A&nbsp;B`, or containing `&eacute;`, `&copy;`, `&ndash;` or `&euro;`
- **WHEN** the guide is parsed
- **THEN** the titles read "Tom & Jerry", "A" then a no-break space then "B", "é", "©", "–" and "€"

#### Scenario: Bare ampersand in an icon link
- **GIVEN** an `icon src` holding a bare `&`
- **WHEN** the guide is parsed
- **THEN** the icon link is read as written

#### Scenario: Entities left alone
- **GIVEN** an unknown name such as `&foo;`, a name in the wrong case such as `&NBSP;`, a name without its semicolon such as `&nbsp`, or a reference to a code point XML forbids such as `&#0;`
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

## ADDED Requirements

### Requirement: Programmes without a stop
The system SHALL keep a programme that has no `stop` attribute and end it where the next programme on the same channel starts, in document order. When no later programme of that channel follows, or the next one does not start later, it SHALL last two hours.

#### Scenario: Back-to-back programmes without stops
- **GIVEN** three programmes on one channel starting at 20:00, 21:00 and 22:30, none with a `stop`
- **WHEN** the guide is parsed
- **THEN** all three are returned, ending at 21:00, 22:30 and 00:30

#### Scenario: Mixed with programmes that have a stop
- **GIVEN** a channel whose programme at 20:00 has no stop and whose next one runs from 20:45 to 21:45, and another channel's programme in between
- **WHEN** the guide is parsed
- **THEN** the first programme ends at 20:45 and the other channel's programme is unaffected

### Requirement: Guide text in Latin-1
The system SHALL read each byte that is not part of valid UTF-8 as Windows-1252 in a guide whose XML declaration names no encoding or names UTF-8. A guide that declares another encoding SHALL be read in that encoding.

#### Scenario: An undeclared Latin-1 guide
- **GIVEN** a guide with no encoding declaration whose titles hold "Bärenstark" and "Fútbol" in Latin-1
- **WHEN** the guide is parsed
- **THEN** it parses and the titles read "Bärenstark" and "Fútbol"

#### Scenario: A declared Latin-1 guide
- **GIVEN** the same guide with `encoding="ISO-8859-1"` in its declaration
- **WHEN** the guide is parsed
- **THEN** the titles read the same
