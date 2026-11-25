## ADDED Requirements

### Requirement: Headings are rounded like the wordmark
Page headings SHALL use the device's rounded system font where the browser offers one, and the plain system font where it does not. Body text, links, lists and the footer SHALL stay in the plain system font. The site SHALL NOT load a font file.

#### Scenario: Safari on an iPhone
- **WHEN** a visitor opens the home page in Safari on an iPhone
- **THEN** the page title and the section headings are rounded and the paragraphs under them are not

#### Scenario: A browser without a rounded face
- **WHEN** a visitor opens the home page in a browser on Windows
- **THEN** the headings are in the system font and nothing is downloaded for them
