# Design: compound components with state in the environment

## Context

The design system (`openspec/specs/design-system/`) draws shared parts, listed
under "Shared components" in its reference, inside three different layouts:
tvOS, iPad and Mac, and iPhone. Each screen has a board in
`openspec/specs/design-system/boards/`. The existing `ChannelsView` mixes
query, loading model, list and navigation in one body, and `ChannelRow` shows
a system glyph for a missing logo, against the design-system requirement
"Channels without a logo show initials". Without a rule, fixes arrive as
`Bool` flags (`showsInitials`, `isTV`, `compact`, `showsProgress`), and each
flag doubles the states a reviewer checks against the board.

Vercel's `composition-patterns` rules for React map onto SwiftUI. The
environment is context, `@ViewBuilder` closures are children, and
`@Observable` with `@Entry` are the current APIs.

Deployment target 26 everywhere (decision adr-0004, deployment target 26),
and every preview is rendered to a PNG in CI (decision adr-0007, export
preview snapshots from CI).

## Goals / Non-Goals

**Goals:**

- A reviewer can tell what kind of view a file is from its folder and check
  it against the rules for that kind.
- Each shared part is drawn and previewed in one place, on every platform it
  ships on.
- A board maps to one screen file.

**Non-Goals:**

- Separate view trees per platform.
- View models per component.

## Decisions

**Three kinds of view, three places under `Apps/Shared/`.**

1. Components (`Components/`). One folder per part in the design system's
   shared components. A component is a namespace enum with sub-views
   (`ChannelRow.Logo`, `ChannelRow.Progress`), each drawing one part. It
   takes values and closures. It never imports SwiftData, never runs a
   `@Query`, never touches the network or the Keychain.
2. Screens (`Views/`). One per design board. The folder keeps the name
   Apple's samples use, so a Swift reader finds screens where they expect
   them. A screen owns the `@Query`, the `@Observable` model, navigation and
   the `.task` that loads. It composes components and installs their shared
   state in the environment. Platform selection with `#if os(...)` happens
   here or in a named variant, once, not inside sub-view bodies.
3. Shell (`RootView`, `Apps/Mobile`, `Apps/TV`). Tabs, scenes, entry points.

**No layout booleans.** No `Bool` initializer parameter chooses a layout. A
different arrangement of parts is a differently named view, such as
`ChannelRow.Overlay` or `ChannelRow.Search`. An enum parameter is fine when
it names mutually exclusive styles of one part, such as `Badge.Style.now`.

**Shared state in one `@Entry` value.** State that more than one sub-view
reads, or actions more than one sub-view fires, go in one environment value
declared with `@Entry`. The value is a struct with `state` (a `Sendable`
value) and `actions` (closures). The screen is the only provider. Sub-views
read it with `@Environment`. Siblings that share state sit under the same
provider and need not be nested visually.

**Composition through `@ViewBuilder` closures.** A closure that takes an
argument is allowed only when the container owns the data it passes, as
`List` and `ForEach` do. No `AnyView` parameters, no `header: some View`
parameters, no `showsFooter` flags.

**Current APIs only.** `@Observable` and `@Environment(Model.self)`, never
`ObservableObject` or `@EnvironmentObject`. `@Entry` for environment keys.
`.task` for loading, never `.onAppear`. No availability checks.

**A preview per variant.** Every component variant has a `#Preview` with
fixture data on every platform it ships on. CI renders each to a PNG, so a
variant without a preview is invisible to reviewers. A component that cannot
be previewed without a screen is a screen.

**The rules live in a skill too.** The `swiftui-composition` skill holds them
with before and after examples. The `implement` skill reads it before writing
a view, and the `impl-reviewer` checks diffs against it.

Options considered:

1. One view per screen with flags and `#if os` inside. The current shape.
   States multiply with each flag, previews need the whole screen, and
   reviewers cannot find the channel row anatomy in one place.
2. A view model class per component (MVVM). A class per row kills previews
   and list performance, and the row owns no state worth a class. Models
   belong to screens.
3. Separate view trees per platform in `Apps/TV` and `Apps/Mobile`. Three
   copies of the channel row drift apart, and the design-system requirement
   "Channel rows share one anatomy" wants one.
4. Keep Vercel's rules as a skill only, with no decision record. A skill
   guides the writer. The folder split and the environment contract bind
   reviewers and the file layout, and that is the part that is hard to
   reverse.

## Risks / Trade-offs

- A component previews alone with fixtures, so "Channel rows share one
  anatomy", "A current programme always shows its progress" and "Channels
  without a logo show initials" are checked in one file per part instead of
  per screen.
- More files per part: a namespace enum, an `@Entry`, a provider and one
  file per variant where one struct used to do.
- The environment is unchecked at compile time. A sub-view rendered outside
  its provider gets the `@Entry` default and shows nothing wrong until
  someone looks. The preview per variant is the guard.
- Follow-up: move `ChannelRow` from `Views/` to `Components/` in the first
  implementing PR and fix its logo fallback there.
- Follow-up: add the skill to the `impl-reviewer` checklist.
