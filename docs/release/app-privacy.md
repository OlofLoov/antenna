# App Store Connect App Privacy answers

These are the answers for App Store Connect, App Privacy, for both the iOS app
(iPhone, iPad and Mac) and the tvOS app. They match the privacy manifests in
`Apps/Mobile`, `Apps/TV` and `Apps/TopShelf`, and the Privacy Policy at
antenna.code-crave.se/privacy.

## Data collection

**Do you or your third-party partners collect data from this app?**
No, we do not collect data from this app.

App Store Connect then shows "Data Not Collected" on the product page, and no
data type or purpose questions follow.

## Why the answer is no

Apple counts data as collected when it leaves the device in a way that lets
the developer or a partner read it for longer than it takes to serve the
request. Antenna sends data to three places, and Code Crave can read none of
them:

- **The user's own sources and guide servers.** Playlists, logins and streams
  go between the device and servers the user chose. Code Crave runs no server
  and never sees the traffic.
- **The user's private iCloud database and iCloud Keychain.** Sources,
  favorites, settings and watch progress sync through CloudKit's private
  database, and logins through the iCloud Keychain. Only the user's own
  devices can read either. The one-time Apple TV login drop is sealed to the
  TV's key and deleted when the TV picks it up or after ten minutes.
- **Apple, for purchases.** StoreKit handles the lifetime unlock and the
  yearly subscription. The app reads the entitlement on the device and keeps
  no receipt. The sales reports in App Store Connect come from Apple's
  records, and the app sends nothing to them.

The app has no analytics, advertising, crash reporting or third-party SDK, and
it does not track. FFmpeg is linked for demuxing and sends nothing.

## Tracking

**Does this app track users?** No. `NSPrivacyTracking` is false and the
manifests list no tracking domains.

## Privacy manifest reasons

The required-reason APIs each bundle declares, for the record when App
Store Connect asks about them:

| Category | Reason | Use |
|----------|--------|-----|
| User defaults | CA92.1 | per-device settings the app reads and writes for itself |
| Disk space | E174.1 | checks free space before the timeshift buffer writes to disk |
| File timestamp | C617.1 | dates of cached posters in the app's container, to evict the oldest |

The Top Shelf extension declares only disk space, for the shared code it
links.

## When this changes

A diagnostics change that sends crash or performance reports, even through a
service we run, adds Crash Data and Performance Data (linked to the user: no;
tracking: no; purpose: App Functionality) here and in the manifests. Update
the Privacy Policy in the same change.
