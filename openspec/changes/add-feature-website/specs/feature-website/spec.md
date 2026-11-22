## ADDED Requirements

### Requirement: The home page says what Antenna is
The system SHALL publish a home page that says in its first screen that Antenna plays the TV sources the visitor already has, on iPhone, iPad, Mac and Apple TV, that it includes no channels, and that it needs a purchase, with a link to Antenna on the App Store.

#### Scenario: A first visit on a laptop
- **WHEN** someone opens the home page on a laptop
- **THEN** without scrolling they read "Your TV sources, on every Apple screen.", the four platforms, that no channels are included, and see the App Store link

#### Scenario: A first visit on a phone
- **WHEN** someone opens the home page on an iPhone
- **THEN** the same line, the platforms and the App Store link show before the first screenshot, with no sideways scrolling

#### Scenario: Before the app is on the App Store
- **GIVEN** Antenna has no App Store page yet
- **WHEN** someone opens the home page
- **THEN** it says "Coming soon to the App Store" in place of the link

### Requirement: Every feature area has a section and a page
The system SHALL show a section on the home page for each feature area (sources, live TV, guide, movies and series, multi-view, Apple TV, setup from iPhone, sync and profiles, privacy), each with a short description, a screenshot and a link to that area's page, and each area's page SHALL describe every feature in it and say which platforms have it.

#### Scenario: Reading about multi-view
- **WHEN** someone follows the multi-view section on the home page
- **THEN** its page says up to four channels play at once, which one is heard, and that it works on Apple TV, iPad and Mac and not on iPhone

#### Scenario: Moving between areas
- **GIVEN** any feature page
- **WHEN** the visitor reaches its end
- **THEN** links lead to the next area and back to the home page

#### Scenario: A screen reader on a feature page
- **WHEN** a screen reader reads a feature page
- **THEN** every screenshot has a description of what it shows, and the headings name the features in order

### Requirement: The site shows only what the app does
The system SHALL describe only features that are in the released app, and SHALL add a feature to the site in the same change that ships it.

#### Scenario: A feature still in a proposal
- **GIVEN** movie scores are proposed but not shipped
- **WHEN** someone reads the movies and series page
- **THEN** it says nothing about scores

#### Scenario: A feature that ships
- **WHEN** a change that adds a feature is archived
- **THEN** the feature's area page describes it, or the change says why it is not shown

### Requirement: Nothing on the site points to a provider
The system SHALL name no IPTV provider, channel, broadcaster, league or streaming service, SHALL show no channel logo or real programme, film or series, and SHALL not say where to buy a subscription.

#### Scenario: Looking at a screenshot
- **WHEN** someone looks at any screenshot on the site
- **THEN** every channel name, logo, programme, poster and backdrop in it is made up

#### Scenario: Asking where to get channels
- **WHEN** someone looks for where to get a source
- **THEN** the site says Antenna plays sources they already have and names none

#### Scenario: Checking the text
- **WHEN** the site check runs
- **THEN** it fails on any page that names a provider, broadcaster, league or streaming service from the listing check's list

### Requirement: Pricing says how buying works
The system SHALL publish a pricing page that says Antenna is free to download and needs a purchase to use, offers a yearly subscription that renews until canceled and a one-time lifetime unlock, that both unlock every feature on every device on the buyer's Apple Account, that both work with Family Sharing, and that the App Store shows the price for the buyer's region before they buy.

#### Scenario: Looking for the price
- **WHEN** someone opens the pricing page
- **THEN** it names the two purchases and says the App Store shows their price for the visitor's region, and no amount is written on the page

#### Scenario: A family
- **WHEN** someone reads whether the family needs to buy again
- **THEN** the page says one purchase covers their Family Sharing group

#### Scenario: Canceling
- **WHEN** someone looks for how to stop the yearly subscription
- **THEN** the page says to cancel in their Apple Account's subscription settings and links to the Terms of Use

### Requirement: Support answers questions and points to the app
The system SHALL publish a support page with answers to common questions and a section saying how to report a problem from the app's Settings on each platform, and SHALL show no email address anywhere on the site.

#### Scenario: A channel will not play
- **WHEN** someone opens the support page with a channel that will not play
- **THEN** an answer says what the app's error message means and what to check, and how to report it from the app

#### Scenario: Looking for an email address
- **WHEN** someone looks on any page for an email address
- **THEN** there is none, and the support and legal pages point to Report a problem in the app

#### Scenario: Restoring a purchase
- **WHEN** someone reads how to unlock Antenna on a new device
- **THEN** an answer says it unlocks on its own with the same Apple Account and how to use Restore Purchases on the paywall

### Requirement: Every page reads without scripts
The system SHALL deliver every page's full text, headings, links and images in the first answer for its address, so the page reads the same with scripts turned off, in a link preview, and to a search engine. A script MAY make moving between pages faster, and SHALL NOT be needed to read any page or follow any link.

#### Scenario: Scripts turned off
- **GIVEN** a browser with JavaScript turned off
- **WHEN** someone opens the Privacy Policy, then follows Pricing in the header
- **THEN** both pages show in full, and the link works as a plain link

#### Scenario: The App Store's privacy link
- **WHEN** App Review or a buyer follows the privacy address from the App Store listing
- **THEN** the first answer for that address holds the whole Privacy Policy

#### Scenario: Sharing a page
- **WHEN** someone pastes the multi-view page's address into a message
- **THEN** the preview shows that page's own title and description, not the home page's

### Requirement: Moving between pages needs no reload
The system SHALL, once a page has loaded with scripts on, open other pages of the site in place without a full reload, keep the header and footer in place, update the address and title, and let the browser's back and forward buttons move between them. A screen reader SHALL announce the new page.

#### Scenario: From a feature page to pricing
- **GIVEN** the multi-view page is open
- **WHEN** the visitor follows Pricing in the header
- **THEN** the pricing page shows without a full reload, the address ends in `/pricing/`, and the title names Pricing

#### Scenario: Going back
- **GIVEN** the visitor moved from the home page to the guide page
- **WHEN** they press the browser's back button
- **THEN** the home page shows again, scrolled to where they left it

#### Scenario: VoiceOver
- **GIVEN** VoiceOver on an iPhone
- **WHEN** the visitor follows a link to another page of the site
- **THEN** VoiceOver reads the new page's title or main heading

#### Scenario: A link to the setup page
- **WHEN** a page of the site links to the setup page and the visitor follows it
- **THEN** the setup page loads as a page of its own, as it does from a setup link

#### Scenario: A mistyped address inside the site
- **WHEN** the visitor follows a link to an address the site has no page for
- **THEN** "Page not found" shows with a link to the home page, as it does when the address is typed

### Requirement: Every page shares one header and footer
The system SHALL show the same header on every page, with Antenna's name linking home and links to Features, Pricing and Support, and the same footer with links to Support, the Terms of Use and the Privacy Policy.

#### Scenario: From the Privacy Policy to pricing
- **GIVEN** the Privacy Policy is open
- **WHEN** the visitor follows Pricing in the header
- **THEN** the pricing page opens

#### Scenario: The setup page
- **WHEN** an iPhone without Antenna opens a setup link
- **THEN** the setup page shows its one line and its App Store link, without the header and footer

### Requirement: Languages are added when their listing is ready
The system SHALL publish the site in English, and SHALL publish another language only when its App Store listing is ready, with every page in that language, its screenshots in that language, and a way to switch between the published languages on every page. Arabic SHALL read right to left.

#### Scenario: English only
- **GIVEN** only English is published
- **WHEN** a visitor whose browser prefers Swedish opens the site
- **THEN** the English site shows, with no language switch

#### Scenario: Swedish is added
- **GIVEN** the Swedish store listing is ready and the Swedish site is published
- **WHEN** a visitor picks Svenska in the language switch
- **THEN** the same page shows in Swedish with Swedish screenshots, at an address that starts with `/sv/`

#### Scenario: A language not yet published
- **GIVEN** only English and Swedish are published
- **WHEN** someone opens an address that starts with `/de/`
- **THEN** "Page not found" shows with a not-found status

#### Scenario: Arabic is added
- **GIVEN** the Arabic site is published
- **WHEN** a visitor opens it
- **THEN** text, navigation and the order of sections run right to left, and screenshots are the Arabic store set
