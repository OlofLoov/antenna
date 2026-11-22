## Purpose

Lets anyone using Antenna tell Code Crave about a problem from inside the app, on every platform, with enough about the app and the last error to act on it, and never with the user's sources, logins or channels. A report reaches the developer privately and the user gets a reference to quote.

## ADDED Requirements

### Requirement: Write a report
The system SHALL offer a Report a problem form on iPhone, iPad, Mac and Apple TV with a required "What happened?" text, an optional topic, an optional email for a reply and a Send button, and SHALL keep Send unavailable until the text holds something other than spaces.

#### Scenario: Opening the form
- **WHEN** the user opens Report a problem
- **THEN** the form shows "What happened?", Topic set to none, "Email for a reply (optional)" and Send
- **AND** the topics offered are Playback, Channels and guide, Movies and series, Sources and sign-in, Purchase and Something else

#### Scenario: Empty text
- **GIVEN** the form with nothing typed, or only spaces and new lines
- **WHEN** the user looks at Send
- **THEN** Send is dimmed, and a line under the text reads "Write what happened to send."

#### Scenario: Long text
- **GIVEN** the user has typed 4,000 characters
- **WHEN** they keep typing
- **THEN** nothing more is added, and a line reads "4,000 of 4,000 characters"

#### Scenario: Apple TV remote and focus
- **GIVEN** the form on Apple TV
- **WHEN** it opens
- **THEN** focus is on "What happened?", and select opens the system keyboard, where an iPhone nearby can type for it
- **AND** focus moves down through Topic, Email and Send, then right to the "What will be sent" list, and Menu closes the form after asking whether to discard the text when there is any

#### Scenario: VoiceOver and large text
- **GIVEN** VoiceOver is on or the text size is large
- **WHEN** the user moves through the form
- **THEN** each field reads its label and its hint, the "What will be sent" list reads as one item per value, and every line wraps

### Requirement: See what will be sent
The system SHALL show, on the form and before Send, a "What will be sent" list with every value the report carries, the text exactly as it will leave the device, and a line saying what is never sent, and SHALL update the list as the user types or changes a field.

#### Scenario: Reading the list
- **GIVEN** an iPhone with Antenna 1.4 (52) on iOS 26.1, one Xtream and one M3U source, and no playback error
- **WHEN** the user types "Guide is empty since this morning" and picks Channels and guide
- **THEN** the list shows the text, "Channels and guide", "Antenna 1.4 (52)", "iOS 26.1", the device model, the app language, "Unlocked", "Sources: Xtream, M3U" and "Last playback error: none"
- **AND** under it the line "Links and logins are removed from your text. Source addresses, names, logins and channels are never sent."

#### Scenario: Text the scrubber changed
- **GIVEN** the user types a sentence holding a link
- **WHEN** the list updates
- **THEN** it shows the sentence with "[link removed]" in place of the link, as it will be sent

#### Scenario: An email given
- **WHEN** the user fills in the email field
- **THEN** the list shows the email, and the line under the field reads "Used only to reply to this report."

### Requirement: Only what helps fix the problem is sent
The system SHALL send in a report only the user's text, the topic, the email when given, the app version and build, the platform and its version, the device model, the app language, whether the app is unlocked, the kinds of sources set up, the last playback error's reason, engine and age, and the diagnostic when ticked.

#### Scenario: No source yet
- **GIVEN** a user who has not added a source
- **WHEN** they send a report
- **THEN** the list and the report say "Sources: none"

#### Scenario: Every source kind
- **GIVEN** sources of every kind the app supports
- **WHEN** a report is built
- **THEN** it lists their kinds once each and nothing else about them

### Requirement: Nothing about sources or the user is sent
The system SHALL NOT send in a report a source's address, name or login, a MAC address, a channel, movie or episode name, a stream link, a profile name, an identifier for the device or the user, or anything from the user's iCloud.

#### Scenario: A report after a failed channel
- **GIVEN** an Xtream source "Acme TV" at a server with a username and password, and its channel "News 24" failed with 404 two minutes ago
- **WHEN** the user sends a report
- **THEN** the report says the source kind is Xtream and the last error was "Stream not found (404)" on the FFmpeg path two minutes before
- **AND** the request holds neither "Acme TV", "News 24", the server name, the username, the password nor the stream link

#### Scenario: A profile and a Stalker source
- **GIVEN** a profile named "Kids" and a Stalker portal signed in with a MAC address
- **WHEN** a report is built
- **THEN** it says "Sources: Stalker" and holds neither the profile name nor the MAC address

### Requirement: Links and logins are removed from the text
The system SHALL replace links, email addresses outside the email field, addresses and login-looking text in the user's text with a marker before showing the list and before sending, and SHALL also remove the addresses, usernames and passwords of the user's own sources wherever they appear. The support service SHALL apply the same rules again before keeping the report.

#### Scenario: A pasted playlist link
- **WHEN** the user types "Nothing loads from http://example.net:8080/get.php?username=viewer&password=secret"
- **THEN** the text sent is "Nothing loads from [link removed]"

#### Scenario: A login written out
- **WHEN** the user types "user: viewer pass: secret123 does not work"
- **THEN** the text sent is "[login removed] [login removed] does not work"

#### Scenario: A Stalker MAC address
- **WHEN** the user types "my MAC 00:1A:79:12:34:56 is blocked"
- **THEN** the text sent is "my MAC [address removed] is blocked"

#### Scenario: An email or a server in the text
- **WHEN** the user types "my provider viewer@example.com said to use 203.0.113.7:8080"
- **THEN** the text sent is "my provider [email removed] said to use [address removed]"

#### Scenario: The user's own password in plain words
- **GIVEN** a source whose password is "sunflower88"
- **WHEN** the user types "I changed my password to sunflower88 yesterday"
- **THEN** the text sent is "I changed my password to [login removed] yesterday"

#### Scenario: A request that skips the app
- **GIVEN** a request that reaches the support service with a link in its text
- **WHEN** the service keeps the report
- **THEN** the kept text has "[link removed]" in its place

#### Scenario: Channel names the user writes
- **WHEN** the user types "News 24 keeps buffering"
- **THEN** the text is sent as written, since the user typed it and sees it in the list

### Requirement: A reply needs an email
The system SHALL send the email only when the user fills in the field, SHALL check that it looks like an email before Send is available, and SHALL say under the field that without an email the report cannot be answered.

#### Scenario: No email
- **GIVEN** the email field empty
- **WHEN** the user reads under it
- **THEN** it says "Without an email, we can read your report but cannot answer it."

#### Scenario: An email that does not look like one
- **GIVEN** "viewer@" in the email field
- **WHEN** the user looks at Send
- **THEN** Send is dimmed and the field says "Check the email address."

### Requirement: Crash and hang reports only when ticked
The system SHALL offer, on iPhone, iPad and Mac and only when the system has delivered one, a box "Attach the latest crash or hang report", off each time the form opens, and SHALL attach that report only while the box is ticked. Apple TV SHALL NOT show the box.

#### Scenario: A crash report exists
- **GIVEN** the system delivered a crash report to Antenna yesterday
- **WHEN** the user opens the form on iPhone
- **THEN** the box shows, unticked, with the date of the report
- **AND** ticking it adds "Crash report from yesterday" to the "What will be sent" list

#### Scenario: Nothing delivered
- **GIVEN** no crash or hang report has reached the app
- **WHEN** the user opens the form
- **THEN** no box shows

#### Scenario: Apple TV
- **WHEN** the user opens the form on Apple TV
- **THEN** no box shows and no diagnostic is sent

### Requirement: A sent report gives a reference
The system SHALL show, once the service has kept the report, a confirmation with a short reference code made of letters and digits, the line "If you write to support@code-crave.se, quote this reference.", and Done, and SHALL clear the form.

#### Scenario: Sent
- **WHEN** the service accepts the report
- **THEN** the confirmation reads "Report sent" and "Reference R-4F7K2Q", or another code of that form
- **AND** Done returns to where the form was opened, and opening the form again shows it empty

#### Scenario: Sent on Apple TV
- **GIVEN** the confirmation on Apple TV
- **WHEN** it shows
- **THEN** Done is focused and select or Menu closes it

### Requirement: A report that cannot be sent stays
The system SHALL keep the text, topic, email and box in the form when a report cannot be sent, say why under Send, and offer Send again. It SHALL NOT queue the report or send it later on its own, and SHALL NOT keep the text after the app quits.

#### Scenario: Offline
- **GIVEN** the device has no internet
- **WHEN** the user chooses Send
- **THEN** the form stays filled in and reads "Couldn't send. You're offline. Your report is still here; send it again when you're connected."

#### Scenario: A slow service
- **GIVEN** the service has not answered
- **WHEN** 20 seconds pass after Send
- **THEN** the spinner stops, the form reads "Couldn't reach Antenna support. Try again in a moment.", and Send works again
- **AND** sending again after a report that did arrive does not make a second report

#### Scenario: Too many reports
- **GIVEN** the service refuses because too many reports came from this network
- **WHEN** the answer arrives
- **THEN** the form reads "Too many reports from this network. Try again in a few minutes."

#### Scenario: Refused
- **GIVEN** the service refuses the report as too large, malformed, or not from Antenna
- **WHEN** the answer arrives
- **THEN** the form reads "Couldn't send this report. Try again later, or write to support@code-crave.se."

#### Scenario: Leaving with unsent text
- **GIVEN** a form with text that has not been sent
- **WHEN** the user closes it
- **THEN** the app asks "Discard this report?" with Discard and Keep editing

#### Scenario: The app quits
- **GIVEN** a form with unsent text
- **WHEN** the app quits and opens again
- **THEN** the form is empty and nothing was sent

### Requirement: Reports reach the developer privately
The system SHALL keep each report as an issue in a private repository that only Code Crave can read, SHALL hold no request log with a report's content or the sender's IP address, and SHALL keep the credential that creates issues on the service only, never in the app.

#### Scenario: Where a report lands
- **WHEN** the service accepts a report
- **THEN** a new issue in the private repository holds the scrubbed text, the topic, the app and device values, the reference code and, when given, the email
- **AND** nothing about it appears in Antenna's public repository

#### Scenario: Looking inside the app
- **WHEN** someone searches the app bundle for a credential that can create issues
- **THEN** there is none

#### Scenario: Looking at the service logs
- **WHEN** the service logs are read after a report
- **THEN** they hold counts and error kinds only, with no text, email or IP address

### Requirement: Only Antenna can send reports
The support service SHALL accept a report only with proof from Apple that it comes from Antenna on a genuine device, App Attest where the device supports it and a DeviceCheck token otherwise, SHALL limit how many reports one network can send, and SHALL refuse a body over its size limit.

#### Scenario: A request from a script
- **GIVEN** a request with a valid body but no proof from Apple
- **WHEN** it reaches the service
- **THEN** it is refused and no issue is made

#### Scenario: A device without App Attest
- **GIVEN** a device where App Attest is not supported
- **WHEN** the user sends a report
- **THEN** the app proves itself with a DeviceCheck token and the report is accepted

#### Scenario: A device with neither
- **GIVEN** a device that supports neither App Attest nor DeviceCheck
- **WHEN** the user opens the form
- **THEN** on iPhone, iPad and Mac Send reads "Send by email" and opens a new mail to support@code-crave.se with the same text and values, and on Apple TV the form says "Reports can't be sent from this Apple TV. Write to support@code-crave.se."

#### Scenario: Many reports from one network
- **GIVEN** ten reports from one IP address in five minutes
- **WHEN** the eleventh arrives
- **THEN** it is refused as too many

#### Scenario: A body too large
- **WHEN** a request larger than the limit arrives
- **THEN** it is refused before any issue is made
