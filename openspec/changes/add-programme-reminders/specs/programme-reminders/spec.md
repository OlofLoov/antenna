# Spec Delta

## Purpose

Lets a viewer who finds a programme that starts later ask to be reminded, so that a few minutes before it starts their iPhone, iPad or Mac notifies them, or any open Antenna shows a banner, and one tap plays the channel.

## ADDED Requirements

### Requirement: Remind me appears only before a programme starts
The system SHALL offer a Remind me button on programmes that have not started, in the Apple TV guide, on the next programmes in the Apple TV channel overlay, and on guide results in Search on iPhone, iPad and Mac, and nowhere else.

#### Scenario: A future programme
- **GIVEN** the user is looking at a programme in the Apple TV guide, a next programme in the Apple TV channel overlay, or a guide result in Search on iPhone, iPad or Mac
- **WHEN** the programme has not started yet
- **THEN** a Remind me button is offered, reachable with the remote on Apple TV

#### Scenario: Current, past and empty slots
- **GIVEN** a programme on now, a past programme, or an empty slot
- **WHEN** the user looks at it in any of those places
- **THEN** no Remind me button is offered

### Requirement: Set a reminder in one tap
The system SHALL save a reminder in one action, mark the button as set, and leave the user where they were without starting playback.

#### Scenario: Set a reminder
- **GIVEN** a programme that has not started and has no reminder
- **WHEN** the user chooses Remind me in any of the places that offer it
- **THEN** the reminder is saved, the button reads "Reminder set", the user stays where they were, and nothing starts playing

#### Scenario: Not signed in to iCloud
- **GIVEN** a device that is not signed in to iCloud
- **WHEN** the user sets a reminder
- **THEN** the reminder is saved, listed and goes off on this device with no error

#### Scenario: Offline
- **GIVEN** a device with no network
- **WHEN** the user sets, receives or removes a reminder
- **THEN** each works as it does online

### Requirement: Remove a reminder anywhere
The system SHALL remove a reminder from every device when the user turns its button off or removes it from the Reminders page, and SHALL deliver nothing for it afterwards.

#### Scenario: Remove a reminder
- **GIVEN** a reminder the user has set
- **WHEN** they turn the button off, or remove the reminder in Settings › Reminders, confirming on Apple TV and Mac
- **THEN** the reminder disappears from every device and no notification or banner arrives for it

#### Scenario: A source is deleted
- **GIVEN** reminders for programmes on a source
- **WHEN** the user deletes that source
- **THEN** its reminders are removed on every device

### Requirement: Choose how early reminders go off
The system SHALL let the user choose, per device, how long before start reminders go off, from at start, 5, 10, 15 or 30 minutes, with 5 minutes until they choose.

#### Scenario: Change the lead time
- **GIVEN** the Reminders page in Settings on one device
- **WHEN** the user picks how long before start to be reminded
- **THEN** they can pick at start, 5, 10, 15 or 30 minutes, with 5 chosen until they pick
- **AND** every upcoming reminder on this device follows the new choice while other devices keep their own

### Requirement: A notification before the programme starts
The system SHALL show a notification on iPhone, iPad and Mac at the chosen time before a reminded programme starts, for reminders set on this or any other device on the same iCloud account.

#### Scenario: The reminder goes off
- **GIVEN** an iPhone, iPad or Mac where Antenna may send notifications, and a reminder set on this or another device
- **WHEN** the chosen number of minutes before start arrives
- **THEN** a notification shows the programme title and "Starts at <time> on <channel>", or "Starts now" when reminding at start

#### Scenario: Set closer to start than the lead time
- **GIVEN** a lead time of 10 minutes
- **WHEN** the user sets a reminder for a programme that starts in 3 minutes
- **THEN** the reminder goes off at once

#### Scenario: Two devices on one account
- **GIVEN** two devices on the same iCloud account that can both notify
- **WHEN** a reminder goes off
- **THEN** both devices remind about it

#### Scenario: A time zone change
- **GIVEN** a reminder set before the device's time zone or daylight saving changes
- **WHEN** the change happens
- **THEN** times show in the current zone and the reminder goes off at the same moment as before

### Requirement: Permission is asked only when it is needed
The system SHALL ask for notification permission only when the user sets their first reminder, after saving it, and SHALL keep the reminder whatever the answer.

#### Scenario: The first reminder
- **GIVEN** an iPhone, iPad or Mac where the user has never been asked about notifications
- **WHEN** they set their first reminder
- **THEN** the reminder is saved first, the system asks once, and the reminder stays saved whatever they answer

#### Scenario: No early prompt
- **WHEN** Antenna launches or Settings opens
- **THEN** Antenna does not ask about notifications

### Requirement: The app says when reminders cannot notify
The system SHALL tell the user on the Reminders page when this device cannot notify, saying reminders show only while Antenna is open, and offer a way to allow notifications where the device has one.

#### Scenario: Notifications unavailable
- **GIVEN** Antenna cannot notify on this device because notifications are off, the user has not been asked yet, or it is an Apple TV
- **WHEN** the user opens Settings › Reminders
- **THEN** a notice says reminders show only while Antenna is open, with a way to allow notifications where the device has one

#### Scenario: Notifications allowed later
- **GIVEN** the notice is showing on an iPhone, iPad or Mac
- **WHEN** the user allows notifications
- **THEN** the notice goes away and upcoming reminders notify

### Requirement: Watch plays the channel
The system SHALL open Live and play the reminder's channel when the user taps its notification or chooses Watch on its banner.

#### Scenario: Watch from a reminder
- **GIVEN** a reminder has gone off, as a notification on iPhone, iPad or Mac or as a banner on any device
- **WHEN** the user taps the notification or chooses Watch
- **THEN** Antenna opens Live and plays the channel, switching to All channels if the group on screen lacks it, leaving it alone if it is already playing, and waiting for its source to load when Antenna was closed

#### Scenario: The channel cannot be found
- **GIVEN** a reminder whose source or login has not synced, or whose channel is gone
- **WHEN** the user taps the notification or chooses Watch
- **THEN** Live opens and nothing plays

#### Scenario: Several channels share one listing
- **GIVEN** several channels that share one guide listing
- **WHEN** the user chooses Watch on a reminder for that listing
- **THEN** the first of them in All channels order plays

#### Scenario: The paid unlock has lapsed
- **GIVEN** the paid unlock has lapsed and a scheduled notification arrives
- **WHEN** the user taps it
- **THEN** the paywall shows instead of the channel, and no banner shows while locked

### Requirement: A banner while Antenna is open
The system SHALL show a reminder as a banner over any screen while Antenna is open, and once on return while a missed programme is still on, without pausing what is playing.

#### Scenario: The reminder goes off in the app
- **GIVEN** Antenna is open on any screen, on iPhone, iPad and Mac only when notifications are off
- **WHEN** the reminder goes off
- **THEN** a banner with the title, start time, channel, Watch and Dismiss appears once over the screen without pausing what is playing, with Watch highlighted on Apple TV

#### Scenario: Returning to a missed reminder
- **GIVEN** a reminder went off unseen and its programme is still on
- **WHEN** the user returns to Antenna
- **THEN** the banner appears once

#### Scenario: Close the banner
- **GIVEN** a reminder banner on screen
- **WHEN** the user chooses Dismiss, presses Menu on Apple TV, or a short time passes
- **THEN** the banner closes and the screen is as it was

### Requirement: Reminders follow a programme that moves
The system SHALL move a reminder to the new time when a guide update moves its programme on the same channel, and mark where it moved from.

#### Scenario: The programme moves
- **GIVEN** a reminder for a programme that a guide update moves to a new time on the same channel
- **WHEN** the updated guide has loaded
- **THEN** the reminder goes off for the new time and its row in Settings › Reminders reads "Moved from <old start>"

#### Scenario: A move of more than six hours
- **GIVEN** a guide update that moves the programme more than 6 hours
- **WHEN** the updated guide has loaded
- **THEN** the programme counts as no longer in the guide and the reminder goes off at the old time

#### Scenario: Two devices disagree for a while
- **GIVEN** two devices with different versions of the guide
- **WHEN** each moves the same reminder
- **THEN** the list may change once before the devices agree

### Requirement: Reminders survive a programme leaving the guide
The system SHALL keep a reminder and its time when a loaded guide covering that time no longer lists the programme, mark it as no longer in the guide, and still deliver it.

#### Scenario: The programme drops out
- **GIVEN** a reminder whose channel's guide has loaded, covers the reminder's time, and no longer lists the programme
- **WHEN** the updated guide has loaded
- **THEN** the reminder keeps its time and still goes off, and its row reads "No longer in the guide"

#### Scenario: The programme comes back
- **GIVEN** a reminder marked "No longer in the guide"
- **WHEN** a later guide lists the programme again
- **THEN** the note clears

#### Scenario: A guide that failed or is too short
- **GIVEN** a guide that failed to load or does not reach the reminder's time
- **WHEN** it is processed
- **THEN** nothing about the reminder changes

### Requirement: See every upcoming reminder in one list
The system SHALL list every upcoming reminder from every device on the same iCloud account once, soonest first, on the Reminders page in Settings.

#### Scenario: The list
- **GIVEN** upcoming reminders set on this or other devices on the same iCloud account
- **WHEN** the user opens Settings › Reminders
- **THEN** each reminder appears once, soonest first, with title, day, start and end time and channel
- **AND** ended programmes are gone and the header shows how many there are

#### Scenario: No reminders
- **GIVEN** no upcoming reminders
- **WHEN** the user opens Settings › Reminders
- **THEN** the page says how to set one
