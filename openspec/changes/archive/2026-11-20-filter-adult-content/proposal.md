# Proposal

## Why

> As a parent who set up Antenna for the family, I want the adult channels, movies and series my provider sends to stay out of sight in every profile until I turn them on with the passcode, so my kids never scroll past them.

On 2026-11-20 the owner asked for "a filter that is applied and needs to be un-applied where we use some sort of filter for 18+ adult content, like per profile". This reverses the 2026-11-12 "parental controls: not now" for this one feature. Time limits, age ratings and a lock on the whole app stay out.

Large IPTV subscriptions often carry adult categories next to the news and sport. Today a household can hide or lock those groups by hand, one by one, on the Groups screen, and movies and series have no such control at all. Hiding is per profile but needs no passcode, and a locked group still shows its name with a lock.

## What Changes

- Antenna finds adult content on its own: the provider's adult flag where the source has one (Xtream `is_adult` on live, movie and series rows and categories, Stalker `censored` on channels and genres, a Jellyfin rating of XXX or AO), and group and category names such as "XXX", "Adult", "18+", "Erotik", "Vuxen" or "للبالغين", matched as whole words with harmless phrases such as "Adult Swim" and "Young adult" left alone.
- Every profile hides adult content by default, everywhere content is listed: channel lists and groups, the Groups sheet, the guide, Movies and Series with their banners and rows, Continue watching, My list, Recently watched, New, Search (people too), multi-view pickers, Top Shelf, Siri and Shortcuts. A hidden channel has no number and no other channel's number changes.
- Settings gains "Show adult content", per profile and synced with it. Turning it on asks for the group passcode, or to set one when there is none. Turning it off never asks. A new profile starts with it off.
- The Groups screen gains an "Adult content" switch on each group, next to Hidden and Locked, so the user can mark a group the app missed or clear one it got wrong. Marks sync to every device of the account.
- A link to adult content, from Top Shelf, Siri, a reminder or the channel restored at launch, asks for the passcode before it plays. Adult content that plays when the filter turns back on stops, as a channel that gets locked does.

Out of scope:
- Age ratings, time limits, a lock on the whole app or on a profile.
- Marking single channels or titles; the user corrects whole groups.
- Correcting movie and series categories by hand. They follow the provider's flag and the name rules only.
- Matching channel or title names; only group and category names are matched, since a word such as "Adult" in a film's title is not a reliable sign.

## Capabilities

### New Capabilities
- `adult-content`: finding adult content, hiding it in every profile by default, the per-profile switch with the passcode, correcting a group, links to hidden content, and what happens to adult content that is playing.

### Modified Capabilities
- `profiles`: what each profile keeps now includes the adult content switch.
- `group-management`: the Groups screen marks groups adult, and syncs those marks with the other group changes.

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV.
- Code: `Packages/AntennaCore` (the name rules, the provider flags in the Xtream, Stalker and Jellyfin decoders, the filter in `Catalogue` and `ShelfIndex`, Siri lookups), `Apps/Shared/Persistence` (one optional field on `GroupRecord`, one defaulted field on `ProfileRecord`), Settings, the Groups screen, the passcode prompt over Live and the Apple TV shell, the shelf model, the intents host and Top Shelf.
- Data: two new fields on existing synced records, both optional or defaulted, so CloudKit migrates lightly.
- Strings: the switch, its footers, the Groups switch and footer, the passcode messages and the Siri reply, in sv, de, es, fr, pt-BR and ar.
- Boards: `iPhone-Settings-Adult`, `iPad-Settings-Adult`, `TV-Settings-Adult`, `iPhone-Groups-Adult`, `iPad-Groups-Adult`, `TV-Groups-Adult`.
- Depends on: `group-management` (the passcode, the prompt, the guessing wait, the reset, the prompt over a channel that gets locked), `profiles` (per-profile sync), `movies-and-series-browsing`, `search`, `top-shelf`, `app-intents`.
- Docs: `docs/release` describes no content filtering, so it is unchanged.
