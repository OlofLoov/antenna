---
name: swiftui-composition
description: Composition rules for SwiftUI views in Apps/Shared. Use when writing or reviewing a screen or component, when a view is growing Bool parameters or #if os branches, when siblings need the same state, or when the user says "component", "compound view", "boolean props", "environment", "variant" or "composition".
---

# SwiftUI composition

Adapted for Swift from Vercel's
[composition-patterns](https://github.com/vercel-labs/agent-skills/tree/main/skills/composition-patterns)
skill (MIT). The rules are theirs, the mapping to SwiftUI and the examples
are ours. The project context in openspec/config.yaml states the rule as a
hard constraint; this file is how to follow it.

React to SwiftUI, for readers who know the original:

| React | SwiftUI |
|-------|---------|
| Context + provider | `@Entry` environment value, set once by the screen |
| `children` | trailing `@ViewBuilder` closure |
| Render prop | closure with an argument, only when the container owns the data |
| `Composer.Input` compound | `ChannelRow.Logo` sub-view inside a namespace enum |
| `useState` lifted to a provider | `@State` or `@Observable` model owned by the screen |
| `forwardRef`, `useContext` | `ObservableObject`, `@EnvironmentObject`, `AnyView`: do not use |

## Three kinds of view

| Kind | Folder | Owns | Never |
|------|--------|------|-------|
| Component | `Apps/Shared/Components/<Part>/` | sub-views, previews | `@Query`, `ModelContext`, network, Keychain, `#if os` in a body |
| Screen | `Apps/Shared/Views/` | `@Query`, `@Observable` model, `.task`, navigation, the environment provider | drawing a part itself that a component owns |
| Shell | `RootView`, `Apps/Mobile`, `Apps/TV` | tabs, scenes, platform entry | screen content |

A file's folder says what rules apply. A component that cannot be previewed
without a screen is a screen.

## Rules

### 1. No Bool that picks a layout

A `Bool` parameter that changes which parts render doubles the states to
review. Three of them is eight rows, and the board only draws one.

Before:

```swift
struct ChannelRow: View {
    let channel: Channel
    var compact = false
    var showsProgress = true
    var isOverlay = false
    var body: some View {
        HStack {
            if !compact { Number(channel.number) }
            Logo(channel)
            if isOverlay { OverlayTitle(channel) } else { Name(channel) }
            if showsProgress && !compact { Progress(channel) }
        }
    }
}
```

After: one named view per arrangement, built from the same parts.

```swift
enum ChannelRow {
    struct Overlay: View { ... }   // number, logo, name, programme, progress
    struct Search: View { ... }    // logo, name with highlight
    struct ZapBar: View { ... }    // logo, name, programme, progress, badges
}
```

An enum parameter is fine when it names styles of one part that cannot
combine: `Badge(.now)`, `Badge(.outline("4K"))`.

### 2. Compound components

A part is a namespace enum. Each sub-view draws one thing the board names.
Variants are composed from the sub-views, so the row anatomy (design-system/channel-rows-share-one-anatomy) lives in one
place and a reviewer can read a variant as a list of parts.

```swift
enum ChannelRow {
    struct Frame<Content: View>: View {
        @ViewBuilder var content: Content
        var body: some View {
            HStack(spacing: 12) { content }
                .frame(minHeight: 64)
        }
    }
    struct Number: View { ... }     // tabular, muted
    struct Logo: View { ... }       // tile with initials fallback, design-system/channels-without-a-logo-show-initials
    struct Name: View { ... }
    struct Programme: View { ... }
    struct Progress: View { ... }   // 3 to 4 pt accent bar, design-system/a-current-programme-always-shows-its-progress
    struct CatchUp: View { ... }    // clock-arrow glyph, trailing
}
```

### 3. Share state through one `@Entry` value

State that more than one sub-view reads, or actions more than one sub-view
fires, go in one environment value. It is a struct with `state` (a
`Sendable` value) and `actions` (closures). The screen provides it, sub-views
read it. A sub-view that takes a single value and nothing else may take it
as an init parameter instead; the environment is for shared state.

```swift
struct ChannelRowContext {
    struct State: Sendable {
        var channel: Channel
        var now: Programme?
        var progress: Double?
    }
    struct Actions {
        var select: () -> Void
        var toggleFavorite: () -> Void
    }
    var state: State
    var actions: Actions
}

extension EnvironmentValues {
    @Entry var channelRow: ChannelRowContext? = nil
}

extension ChannelRow {
    struct Progress: View {
        @Environment(\.channelRow) private var row
        var body: some View {
            if let fraction = row?.state.progress {
                ProgressBar(fraction: fraction)
            }
        }
    }
}
```

The default is `nil` so a sub-view used outside its provider renders
nothing rather than a wrong value. The preview per variant (rule 8) is what
catches it.

### 4. Lift state to the screen

State lives in the view that provides it. Siblings share it by sitting
under the same provider, not by being nested in each other.

Three shapes to delete on sight:

```swift
// State trapped in a leaf; the sibling cannot read it
struct SearchField: View { @State private var query = "" ... }

// Echoing state up through onChange
.onChange(of: query) { _, new in onQueryChange(new) }

// A Binding threaded through three views that do not use it
SearchScreen -> SearchColumn(query: $query) -> SearchHeader(query: $query) -> SearchField(query: $query)
```

Instead:

```swift
struct SearchScreen: View {
    @State private var model = SearchModel()
    var body: some View {
        HStack {
            SearchField()
            ResultsList()
        }
        .environment(\.search, SearchContext(
            state: .init(query: model.query, results: model.results),
            actions: .init(setQuery: { model.query = $0 }, select: model.select)
        ))
        .task(id: model.query) { await model.run() }
    }
}
```

`SearchField` and `ResultsList` are siblings. Neither knows about the other
or about `SearchModel`.

### 5. Components take values, screens load data

A component never runs a `@Query`, reads a `ModelContext`, hits the network
or the Keychain. The screen does that and hands values down. The same
component then works in a preview with fixtures, in a snapshot in CI, and
under a different screen tomorrow.

Before:

```swift
struct FavoriteButton: View {
    @Environment(\.modelContext) private var context
    @Query private var favorites: [FavoriteRecord]
    let channelID: String
    ...
}
```

After:

```swift
struct FavoriteButton: View {
    let isFavorite: Bool
    let toggle: () -> Void
}
```

The `Bool` here names a state of the data, not a layout. That is allowed.

### 6. Explicit variants

Each variant names its provider, its parts and its actions. The reader does
not have to evaluate flags to know what is on screen.

```swift
extension ChannelRow {
    struct Overlay: View {
        let state: ChannelRowContext.State
        let actions: ChannelRowContext.Actions
        var body: some View {
            Frame {
                Number()
                Logo()
                VStack(alignment: .leading, spacing: 4) {
                    Name()
                    Programme()
                    Progress()
                }
                CatchUp()
            }
            .environment(\.channelRow, .init(state: state, actions: actions))
        }
    }
}
```

The tvOS and iPhone overlay rows differ in size and focus, not in anatomy.
Size comes from the environment (`horizontalSizeClass`, a platform
constant), focus from `.focusable` on the frame. If they differ in anatomy,
they are two variants, not one with `#if os(tvOS)` in the middle of the
body.

### 7. Children over view parameters

Compose with a `@ViewBuilder` closure. Do not take `header: AnyView`,
`footer: () -> some View` with no argument, or a `showsFooter` flag.

Before:

```swift
SectionHeader(title: "Sports", trailing: AnyView(Text("See all")))
```

After:

```swift
SectionHeader(title: "Sports") {
    SeeAllLink(destination: .group("Sports"))
}
```

A closure with an argument is right when the container owns the data it
passes back, exactly like `List` and `ForEach`:

```swift
PosterRow(titles) { title in
    ContentCard.Poster(title: title)
}
```

### 8. Current APIs, one preview per variant

- `@Observable` models, read with `@Environment(Model.self)` or passed by
  value. Never `ObservableObject`, `@StateObject`, `@EnvironmentObject`.
- `@Entry` for environment keys. Never a hand-written `EnvironmentKey`.
- `@Bindable` to bind into an `@Observable` model.
- `.task` and `.task(id:)` for loading. Never `.onAppear { Task { } }`.
- No `AnyView`. Generics or `@ViewBuilder` instead.
- No availability checks. Deployment target is 26.
- Every variant has a `#Preview` with fixture data, deterministic: no
  network, no clock, in-memory `ModelContainer` if a screen needs one. CI
  renders each preview to a PNG, so a variant without a preview is invisible
  to reviewers.

## Review pass

Run these over a diff before `/opsx:verify`. Each hit is a finding unless
the PR body names the rule and the reason.

```sh
grep -rnE 'var [a-zA-Z]+ = (true|false)|: Bool' Apps/Shared/Components
grep -rn '#if os' Apps/Shared/Components
grep -rnE '@Query|modelContext|URLSession|CredentialStore' Apps/Shared/Components
grep -rnE 'AnyView|ObservableObject|EnvironmentObject|StateObject|EnvironmentKey|onAppear' Apps/Shared
grep -rn 'onChange' Apps/Shared
```

Then by eye: a `Bool` in a component init names data, not layout (rule 5
versus rule 1). Every variant has a `#Preview`. Every `@Entry` is set by
exactly one screen.
