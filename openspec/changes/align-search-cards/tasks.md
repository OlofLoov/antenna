## 1. Shared components take what Search needs

- [x] 1.1 `Browse.ChannelRow` and `ChannelOverlay.ChannelRow` take highlight ranges for the name and the second line
- [x] 1.2 `ShelfView.PosterCard` takes the kinds that wear their badge and an identifier
- [x] 1.3 `TitlePage.Chip` takes a name, its ranges and a muted trailing view; the title page passes "Director"
- [x] 1.4 `GuideBoard.NowBadge` is shared by the guide card and Search
- [x] 1.5 `SearchText.channelRowLine` in AntennaCore, with a core test

## 2. Search draws them

- [x] 2.1 Channels are the Live list's row on iPhone, iPad and Mac and the channel list's row on Apple TV, two across there, reading the Live list's guide line
- [x] 2.2 Programmes take the guide's surface, corner, NOW badge, progress bar and, on Apple TV, the white focus card
- [x] 2.3 Movies and series are the shelf's poster card with its menu and the highlighted name under it; the screens set the shelf and Live list sizes
- [x] 2.4 People are cast chips in a sideways row
- [x] 2.5 The keyboard cursor is the Live list's ring on every result
- [x] 2.6 `SearchRow.Channel`, `SearchRow.Title`, `SearchRow.Person` and Search's own NOW badge are gone; previews draw the shared components

## 3. Boards

- [x] 3.1 `iPhone-Search`, `iPhone-Search-People`, `iPad-Search`, `iPad-Search-Capped`, `iPad-Search-GuideLoading` and `TV-Search` draw the shared cards

## 4. Verify

- [x] 4.1 UI tests citing `search/results-grouped-best-first` pin a Search poster to the Movies poster's size and a Search channel row to the Live list's (iPhone) and channel list's (Apple TV) row height
- [x] 4.2 The Search UI test classes pass on the iPhone and Apple TV simulators
- [x] 4.3 /opsx:verify passes
