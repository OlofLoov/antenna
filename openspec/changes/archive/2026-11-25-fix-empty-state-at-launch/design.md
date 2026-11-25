# Design

## Context

iPhone, iPad and Mac read one `LiveStatus` for Live's list and the Guide. `LiveStatus(sources:dismissed:)` turned `.channels` as soon as a source's state was `.loaded(channels: n > 0)`. `LiveModel.finish` sets that state and starts `startCatalogueBuild`, which runs away from the main actor. Until it lands, `catalogue` is the empty one from launch, `rows` is empty, and the list showed `Browse.EmptyGroup` ("No channels match.") while the Guide showed `GuideBoard.Empty` ("No channels in All channels"). A large playlist keeps that up for a visible moment.

On Apple TV `ShellModel.liveScreen` was `.empty` whenever nothing was tuned and no source was loading. Since `reopen-on-what-you-watched-last`, `considerTune` waits while `launchTitle.holds`, up to 10 seconds, so a launch after a movie showed "No channels yet" once Live's sources finished and before the movie's section listed the title. The tvOS Guide had no loading state at all; its grid said "No channels in All channels" while the sources loaded.

## Decisions

### Loading until the channels are listed

`LiveModel.listed` is true once a catalogue built from a non-empty channel list has landed. `LiveStatus.init(sources:dismissed:listed:)` returns `.loading(sources)` while any source loads, or while a source has channels and `listed` is false. A refresh keeps `listed` from the previous build, so reloading a source never brings the loading rows back over channels already shown.

`ShellModel.liveScreen` returns `.empty` only when every source added nothing (`addedNothing` on each, which holds for no sources too). With channels loaded and nothing tuned it stays `.loading`, the screen that lists each source with its count. `ShellModel.listed`, set by `ShellView` when a catalogue lands, and `channelsPending` give the Guide the same answer: "Loading channels" in the grid, reusing the string the loading screen already has, before the empty group text.

Options considered:
- Delay the empty state by a fixed time (rejected): it hides the symptom for small playlists and still flashes for large ones on a slow device.
- Treat an empty catalogue as loading (rejected): a profile whose group rules hide every channel would read as loading forever.
- Track whether the catalogue on screen came from loaded channels (chosen): the state that decides the screen is the one that fills it.

## Platforms

iPhone, iPad and Mac through `LiveStatus`, Apple TV through `ShellModel`. Movies and Series already hold a loaded source's state in `pendingStates` until the index with its titles lands. Onboarding reads the store through `@Query`, which is filled on the first frame.

## Boards

None change. The loading rows and the Apple TV loading screen are the existing `iPhone-Loading`, `iPad-Loading` and `TV-Shell-Loading` boards, and the Apple TV Guide's "Loading channels" sits where `TV-Guide-Empty` puts the empty group text. Design-system requirement followed: `empty-and-error-states-share-one-layout`.
