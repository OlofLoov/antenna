# Search cards that match the rest of the app

## Why

The owner, on iPhone: "in the search view, the cards need to be more consistent with the rest of the app."

Search drew its own copies of every card. Its channel rows sat on a gray surface, put the number in the second line and had no progress bar, while the Live list puts the number after the name and a progress bar under the programme. Its posters were 108 by 162 on iPhone and 180 by 270 on Apple TV, where Movies draws 110 by 165 and 212 by 318, and on Apple TV they took the iPhone corner. A poster in Search had no menu, so More info and My list were only on the Movies and Series tabs. People were rows with an initials circle, where the title page shows the same people as chips. Programmes on Apple TV took the system's gray bordered platter where the guide uses its own surface and the white focus card.

A movie and series watcher who finds a title in Search now sees the poster they know from Movies, at the same size, and can long-press it for More info or My list. A living-room viewer sees channels in Search the way the channel list shows them.

## What Changes

- Movies and series in Search are the Movies tab's poster card: same size, corner, name tile and menu (More info on a movie, Add to or Remove from My list). The name with its highlight sits under the poster, as under a Continue watching card, and a series carries the SERIES badge.
- Channels in Search are the Live list's channel row on iPhone, iPad and Mac, and the channel list's row on Apple TV: logo tile, name with the number after it, what is on now and its progress bar, the catch-up mark. A channel found by its group says so in the programme's place.
- Programmes in Search take the guide's programme look: the guide's surface and corner, its NOW badge, and the progress bar along the foot of a programme on now. On Apple TV the row rests on the guide's surface and takes the white focus card.
- People in Search are the title page's cast chips, the name highlighted and the "Acting · 9 in your sources" line muted inside the chip, in a row that scrolls sideways.
- Apple TV lists channels two across, as it lists programmes, instead of a row of cards.
- The keyboard cursor on iPad and Mac is the Live list's 2 pt ring on every result instead of a brighter surface.

Out of scope:
- How posters load and cache. Search keeps the shelf's loader; only the card around it changes.
- The Search field, chips, section headers, recent searches and messages.
- Which results show and their order.

## Capabilities

### Modified Capabilities

- `search`: `Results grouped, best first` says each kind of result looks the way the rest of the app shows it, with the poster menu on movies and series.

## Impact

- `Apps/Shared/Components/` Search, Shelf (`ShelfView.PosterCard` gains a badge and an identifier), Browse and ChannelOverlay (channel rows take highlight ranges), Title (`TitlePage.Chip` takes a name and a trailing view), GuideBoard (the NOW badge is shared).
- `Apps/Shared/Views/Search/`: the feed builds the shared rows; channels read the Live list's guide line.
- `SearchText` in AntennaCore gains the channel row's second line without the number.
- Boards `iPhone-Search`, `iPhone-Search-People`, `iPad-Search`, `iPad-Search-Capped`, `TV-Search`.
- Depends on nothing open. Nothing blocks it.
