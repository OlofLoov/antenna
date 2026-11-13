## MODIFIED Requirements

### Requirement: Header EPG URLs
The system SHALL read the guide links named by the `url-tvg`, `x-tvg-url` and `tvg-url` attributes of every `#EXTM3U` line, split on commas, with spaces around each entry trimmed and empty entries skipped. Per header line the `url-tvg` links SHALL come first, then the `x-tvg-url` links, then the `tvg-url` links, each in the order written. Links from later header lines SHALL follow, and repeats SHALL be kept.

#### Scenario: Two guide links in the header
- **GIVEN** a header `#EXTM3U url-tvg="http://a/epg.xml,http://b/epg.xml.gz"`
- **WHEN** the playlist is parsed
- **THEN** the guide links are `http://a/epg.xml` and `http://b/epg.xml.gz`, in that order

#### Scenario: Both attributes and a second header line
- **GIVEN** `#EXTM3U x-tvg-url="http://x" url-tvg="http://u"` followed later by `#EXTM3U url-tvg="http://third"`
- **WHEN** the playlist is parsed
- **THEN** the guide links are `http://u`, `http://x` and `http://third`, in that order

#### Scenario: Blank entries
- **GIVEN** `url-tvg=""`, or `url-tvg=" http://a , ,http://b"`
- **WHEN** the playlist is parsed
- **THEN** the first gives no guide link and the second gives `http://a` and `http://b`

#### Scenario: A junk guide link survives as a relative link
- **GIVEN** a `url-tvg` entry that is not a well-formed URL, such as `b c`
- **WHEN** the playlist is parsed
- **THEN** the entry is kept as a relative link with its invalid characters percent-encoded (`b%20c`), and is dropped only when no link can be formed at all

#### Scenario: The tvg-url spelling
- **GIVEN** a header `#EXTM3U tvg-url="http://t/epg.xml.gz"`
- **WHEN** the playlist is parsed
- **THEN** the guide link is `http://t/epg.xml.gz`

#### Scenario: All three spellings on one line
- **GIVEN** `#EXTM3U tvg-url="http://t" x-tvg-url="http://x" url-tvg="http://u"`
- **WHEN** the playlist is parsed
- **THEN** the guide links are `http://u`, `http://x` and `http://t`, in that order
