# Design

## Context

Group rules reach every channel list through one value. `GroupStore.rules` builds `GroupRules` from the synced group records and the current profile, `GroupRulesFeed` hands them to Live and the Apple TV shell, and `Catalogue` applies them in `CataloguePolicy`: hidden groups leave All channels, locked channels leave every group and lose their number, and every screen that lists channels, counts them, searches them or types a number asks the catalogue. Siri's `ChannelMatcher`, `SearchChannel.all`, `IntentLookup.suggestedChannels`, `NewChannels` and Top Shelf's favorites read the same catalogue.

Movies and series come from `ShelfIndex`, built off the main actor by `ShelfModel` each time a source's titles change. The banner, the rows, the grid, Continue watching, Recently watched, My list, the people index and Search all read `ShelfIndex.titles` or `ShelfIndex.title(_:)`. Siri's title lookups in the background read the loaded titles directly.

The group passcode exists (`PasscodeRecord`, `GroupLocks`, `PasscodePrompt`), with the guessing wait, the reset on iPhone, iPad and Mac, and the full-screen prompt on Apple TV. `GroupLockPrompt` pauses a channel that becomes locked and covers it with the prompt.

## Boards

- `iPhone-Settings-Adult` (new): the top of Sources & Settings with Profiles, Groups and the "Show adult content" switch off, with its footer.
- `iPad-Settings-Adult` (new): the same list on iPad and Mac, switch on, with the footer for the on state.
- `TV-Settings-Adult` (new): the Apple TV split page with the switch focused and its footer in the lead column.
- `iPhone-Groups-Adult` (new): a provider group's settings with Hidden, Locked and "Adult content" on, and its footer.
- `iPad-Groups-Adult` (new): the Groups split on iPad and Mac in a profile that hides adult content, with the list's note and a group's editor with "Adult content" off.
- `TV-Groups-Adult` (new): the Apple TV Groups list with the ADULT badge on the focused row and the panel with the switch.
- `TV-Groups-Locked` (changed): Cancel under the keypad.

Design-system requirements followed: `design-system/controls-use-system-styles` (system `Toggle`s in the existing Forms and Lists), `design-system/forms-use-the-platform-form-style`, `design-system/modals-are-system-presentations` (the passcode prompt keeps its sheet and full-screen cover), `design-system/type-uses-text-styles`, `design-system/accessibility-identifiers-follow-the-board`, `design-system/copy-fits-in-every-language`, `design-system/layouts-mirror-in-right-to-left-languages`.

Not drawn: the passcode prompt with the adult message, which is `iPhone-Groups-Locked`, `iPad-Groups-Locked` and `TV-Groups-Locked` with another sentence; the ADULT badge on iPhone and iPad rows, which is the HIDDEN and LOCKED badge with another word; the Settings switch on a Mac, which is the iPad list in the Mac Form.

## Decisions

### Detection lives in AntennaCore, on group and category names and the provider's flags

`AdultContent.isAdultName` folds case and accents, splits the name into words (runs of letters and digits, and "+" as a word of its own), and answers true when a word is on the adult list or the words "18 +" or "+ 18" appear, unless every adult word sits inside a harmless phrase. The lists:

- Adult words: xxx, porn, porno, pornos, pornography, hentai, erotic, erotica, erotik, erotique, erotico, eroticos, eroticas, erotiek, adult, adults, adulte, adultes, adulto, adultos, adulta, adultas, vuxen, vuxna, vuxenfilm, erwachsene, erwachsenen, voksen, voksne, 18plus, للبالغين, بالغين, للكبار.
- Adult phrases: "18 +", "+ 18" (so "18+", "+18" and "(18+)").
- Harmless phrases: adult swim, young adult(s), new adult, adult contemporary, adult education, adult animation, adult learning, adult alternative, junge erwachsene, unga vuxna, jóvenes adultos, jeunes adultes, jovens adultos.

The provider's flags: Xtream `is_adult` on live streams, movie and series rows and on categories (1, "1" or true; anything else is false), Stalker `censored` on channels and genres, and a Jellyfin `OfficialRating` of XXX or AO. Channels DVR sends no such flag, so its channels go by their group name only. `Channel.isAdult` and `ShelfTitle.isAdult` carry the flag; neither is encoded.

`Fixtures/Adult/names.json` lists every rule with a name that should match and one that should not, and the provider fixtures cover each flag.

Options considered:
- Names only (rejected): Xtream and Stalker panels flag categories whose names say nothing, such as "Night Shows".
- Also match channel and title names (rejected): "Adult" in a film's title or "Erotic Thriller" is not a reliable sign, and the user can only correct whole groups. A flagged channel in a plain group is hidden on its own.
- NC-17, R18 and FSK 18 as adult (rejected): they also rate violent films that are not adult content.
- A group whose every channel the provider flags is adult as a whole (chosen), so it does not stay listed as an empty group.

### The filter sits in the catalogue and the shelf index, hiding by default

`GroupRules` gains `adultMarks: [CatalogueGroup: Bool]` (the user's corrections) and `showsAdult: Bool`, false by default. `GroupRules()` therefore hides adult content: a screen that builds a catalogue and forgets the switch hides too much, never too little. `CatalogueIndex` finds the adult-named groups and whether any channel is flagged once per load, so a catalogue without adult content keeps the fast path with no policy.

While `showsAdult` is false, `CataloguePolicy` marks every adult entry blocked, as a lock does, so it leaves every group, count, number, digit match and search, and other numbers stay. Unlike a lock, an adult group is listed nowhere: not in `groups`, not in `lockedGroups`, not in `managedGroups`, not among the orphaned settings. `Catalogue.isLocked(_:)` stays false for an adult entry and `isAdultHidden(_:)` answers for it, so the lock prompt and the adult prompt can say different things.

`ShelfIndex(catalogues:showsAdult:now:)` and `ShelfIndex.build` take the switch as a required argument. Unless it is set, adult titles leave `titles`, `newest`, `rows` and `banner` before anything else is built, so Continue watching, Recently watched, My list, the people index and Search, which all read the index, follow without a change. `withheldTitle(_:)` answers for a link to a title the index left out. `[ShelfTitle].visible(showsAdult:)` and `IntentLookup.title(_:in:showsAdult:sources:)` cover Siri's background path, which reads titles without an index.

Options considered:
- Filter in each screen (rejected): the owner listed more than a dozen places, and one forgotten view would show adult content.
- Hide adult groups the way hidden groups hide (rejected): hidden groups stay searchable on request and keep their channels' numbers reachable by digits.
- Treat adult groups as locked groups (rejected): a locked group shows its name with a lock, and the owner wants adult content out of sight.

### The switch is a field on the profile record and stays on

`ProfileRecord.showsAdult: Bool = false` and `Profile.showsAdult`. It syncs with the profile, a new profile starts off, and deleting a profile deletes it. With one profile there may be no stored record; turning the switch on stores Main's record, as renaming Main does today. `ProfileStore.setShowsAdult(_:_:in:)` writes it, and the screens read it through the `showsAdultContent` environment value set next to `currentProfile` in `ProfileGate`.

Options considered:
- A new synced record per profile (rejected): one more record type to resolve duplicates for, for one bit the profile record can carry.
- Per device in `UserDefaults` (rejected): the owner asked for it per profile, and a parent would have to turn it on on every device.
- Close again like the locks, on reopening or after 15 minutes (rejected, recommended to the owner): the profile is what separates the people in a household. A parent who turned it on in their own profile would type the passcode on every launch, and the kids' profiles stay filtered either way. The locks close on their own because a locked group lives in a profile everyone shares; this switch belongs to one profile. The risk: profiles have no passcode, so a child who picks a parent's profile sees what the parent sees. A profile passcode is a separate decision.

Turning it on asks for the passcode with `PasscodeFlow.unlock`, or `.create` when the account has no passcode, so the guessing wait, the reset on iPhone, iPad and Mac and the Apple TV prompt come with it. The right passcode also opens the group locks on this device, as it does everywhere else; nothing in the prompt can tell the two apart. Turning it off writes at once.

### Corrections are a field on the group record

`GroupRecord.adult: Bool?`: nil follows the name rules and flags, true marks the group adult, false clears it. It is account-wide like `locked`, because whether a group holds adult content does not depend on who watches. `GroupStore.setAdult(_:_:in:)` writes it, and `GroupStore.rules` reads it into `adultMarks` together with the profile's switch. The Groups screen shows the switch for provider groups and own groups, not for All channels, and lists adult groups only while the profile shows adult content, with an ADULT badge. While they are hidden, a footer says how to see them.

Movie and series categories have no screen to correct them, so their filter is the flag and the name rules only. A category the rules miss can still be hidden by the provider's flag; a wrong match shows once the profile shows adult content.

### Playing adult content and links reuse the lock prompt

`GroupLockPrompt` learns a second reason to cover the picture: the playing channel is adult and hidden. It pauses, shows `PasscodePrompt` with "Adult content is hidden in this profile.", and the right passcode turns the switch on for the profile and resumes. Closing it plays the first channel the profile may watch, or stops, as for a locked channel. That one path covers the switch turning off on this device or another, a profile change, the channel restored at launch, Control Center, a reminder and a channel link from Top Shelf or Siri, since each of them tunes first.

Titles take a shorter path. Siri and Shortcuts resolve a title before Antenna opens, and `IntentLookup.title` answers `adultHidden` for an adult title the profile hides, so Siri says so and nothing opens. Top Shelf only lists titles from the filtered index, so a tile for an adult title exists only from before the switch went off; selecting it finds no title and opens Antenna as it was, as for any tile that no longer matches. An adult movie or episode that plays when the switch goes off closes the player (`ShelfSync`).

Options considered:
- A passcode prompt for title links too, kept pending until the index is rebuilt (rejected for now): Siri refuses before the app opens, so only a stale Top Shelf tile would reach it, and it needs a second prompt host at the root on every platform.
- A one-time pass that plays without turning the switch on (rejected): adult content would play in a profile that hides it, and Continue watching would then show a title the rest of the app hides.

### Cancel under the keypad on Apple TV

The Apple TV UI test for the switch found that focus stayed on Cancel in the prompt's top-left corner: pressing down from there never reached the keypad in the middle, so the passcode could not be typed with the remote. On Apple TV, Cancel now sits under the keypad, after Forgot passcode, while the prompt shows its keys; the waiting-for-iCloud prompt keeps it in the corner. This fixes the group lock prompt as well. `TV-Groups-Locked` draws Cancel under the keypad.

### Identifiers

- `settings.adultContent`: the switch. `settings.adultContent.footer`: its footer.
- `groups.adult`: the switch in a group's settings. `groups.adultHidden`: the Groups list's note. `groups.badge.adult`: the badge.
- The prompt keeps `groups.passcode.*`.
- Launch argument for UI tests: `-ui-testing-adult` adds "XXX Night", number 90, in the group "XXX" to the first scripted playlist on iPhone and Apple TV, and sets the passcode 2580.

### Data

Two fields on existing synced records, `ProfileRecord.showsAdult` (defaulted) and `GroupRecord.adult` (optional). Both are lightweight CloudKit migrations; an older build ignores them. An older build on another device does not filter, which the release notes need not mention before 1.0 ships.
