# Tasks

## 1. Entry and routing

- [x] 1.1 Show the welcome screen when the user has paid and has no provider, with no network call, and verify with a UI test citing `first-run-onboarding/a-new-user-is-asked-for-a-provider`
- [x] 1.2 Route a user with a usable provider straight to channels, and a user on iPhone, iPad or Mac waiting for a synced password to Live, and verify with an integration test citing `first-run-onboarding/a-returning-user-goes-straight-to-their-channels`
- [ ] 1.3 Replace onboarding with the purchase screen when the purchase lapses, keep a saved provider, and verify in the same UI test as 1.1. Open: no purchase screen or entitlement exists until change `add-paywall-and-entitlement` is built.

## 2. Add-source form and connect

- [x] 2.1 Build the provider type picker and fields on tvOS and the shared sheet, with Stalker shown but disabled, and verify against the onboarding boards
- [x] 2.2 Validate through the `source-management` rules before any network call and verify with an integration test citing `first-run-onboarding/mistakes-in-the-form-are-caught-before-connecting`
- [x] 2.3 Map rejected login, inactive account, server error, unreadable reply, unreachable and offline to their messages, keep the fields, save nothing, and verify with an integration test citing `first-run-onboarding/a-failed-connection-says-why-and-saves-nothing`
- [x] 2.4 Save or reuse the provider and store its password in the Keychain, and verify with an integration test citing `first-run-onboarding/a-working-provider-is-saved-once`
- [x] 2.5 Detect a copied link without reading the pasteboard, read it only on Fill in, route it to Xtream or playlist fields, show no banner on macOS, and verify with an integration test citing `first-run-onboarding/fill-the-form-from-a-copied-link`

## 3. Loading checklist and summary

- [x] 3.1 Drive checklist lines from the Connect response, the catalogue build and the guide download, with real counts, the 20 second movies cutoff and no guide line when there is no guide, and verify with an integration test citing `first-run-onboarding/the-checklist-shows-real-progress`
- [x] 3.2 Build the summary that leaves out empty and failed parts and plays the first channel behind it on tvOS, and verify with an integration test citing `first-run-onboarding/a-summary-when-everything-has-loaded`
- [x] 3.3 Offer Browse movies, or only Back for a provider with nothing, removing what the attempt saved, and verify with an integration test citing `first-run-onboarding/a-provider-with-no-live-channels`

## 4. Start watching and a second provider

- [x] 4.1 Close onboarding on Start watching and play the first channel while the guide keeps loading, and verify with a UI test citing `first-run-onboarding/start-watching-without-waiting-for-the-guide`
- [x] 4.2 Add another source from the summary, add up both providers' numbers and keep the first guide download running, and verify with an integration test citing `first-run-onboarding/add-a-second-provider`

## 5. Apple TV sign-in

- [x] 5.1 Ask for each Xtream provider's username and password on Apple TV with the server filled in, store each under the record's credential key, skip Stalker, and verify with an integration test citing `first-run-onboarding/sign-in-again-on-an-apple-tv`

## 6. Verify

- [x] 6.1 Each requirement has a test citing `first-run-onboarding/<requirement-slug>`
- [ ] 6.2 `/opsx:verify` passes. Open until 1.3 can be done.
