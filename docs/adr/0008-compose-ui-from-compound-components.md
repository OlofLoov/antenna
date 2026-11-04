# 0008. Compose UI from compound components with state injected through the environment

- Status: Proposed
- Date: 2026-11-04
- Related specs: 0006 to 0012, 0015

## Context

One app, three layouts. `docs/design/README.md` draws the same parts on
every platform (channel row, programme progress bar, badges, section header,
content card) inside layouts that differ completely between tvOS, iPad and
Mac, and iPhone. Every board in `docs/design/boards/` is waiting for code.

The two views that exist already show where this goes without a rule.
`ChannelsView` owns the SwiftData query, the loading model, the list and the
navigation in one body. `ChannelRow` draws a system glyph when the logo is
missing, which DR-8 forbids, and the fix will be tempting to make with a
`showsInitials: Bool` parameter. A few more screens like this and every
shared view carries `isTV`, `compact`, `showsProgress` flags, each doubling
the states a reviewer has to check against the board.

Vercel's `composition-patterns` skill solves this problem for React with
eight rules: no boolean prop sprawl, compound components, state lifted into
a provider, a generic context contract, explicit variants, children over
render props. SwiftUI has the same primitives under other names: the
environment is context, `@ViewBuilder` closures are children, `@Observable`
plus `@Entry` are the modern APIs. The rules translate almost one to one.

## Decision

Shared UI is built from three kinds of view, in three folders under
`Apps/Shared/`. A reviewer can tell which kind a file is from its folder and
check it against the rules for that kind.

1. **Components** (`Components/`). One folder per part named in design
   section 3. A component is a namespace enum with sub-views
   (`ChannelRow.Logo`, `ChannelRow.Progress`), each drawing one part. It
   takes values and closures. It never imports SwiftData, never runs a
   `@Query`, never touches the network or the Keychain.
2. **Screens** (`Views/`). One per design board. The folder keeps the
   name Apple's samples use, so a Swift reader finds screens where they
   expect them. A screen owns the `@Query`, the `@Observable` model,
   navigation and the `.task` that loads. It composes components and
   installs their shared state in the environment. Platform selection
   with `#if os(...)` happens here or in a named variant, once, not inside
   sub-view bodies.
3. **Shell** (`RootView`, `Apps/Mobile`, `Apps/TV`). Tabs, scenes, entry
   points.

Within those kinds:

- No `Bool` initializer parameter chooses a layout. A different arrangement
  of parts is a differently named view: `ChannelRow.Overlay`,
  `ChannelRow.Search`. An enum parameter is fine when it names mutually
  exclusive styles of one part, such as `Badge.Style.now`.
- State that more than one sub-view reads, or actions more than one
  sub-view fires, go in one environment value declared with `@Entry`. The
  value is a struct with `state` (a `Sendable` value) and `actions`
  (closures). The screen is the only provider; sub-views read it with
  `@Environment`. Siblings that share state sit under the same provider and
  need not be nested visually.
- Composition is a `@ViewBuilder` closure. A closure that takes an argument
  is allowed only when the container owns the data it passes, as `List`
  and `ForEach` do. No `AnyView` parameters, no `header: some View`
  parameters, no `showsFooter` flags.
- Current APIs only: `@Observable` and `@Environment(Model.self)`, never
  `ObservableObject` or `@EnvironmentObject`; `@Entry` for environment
  keys; `.task` for loading, never `.onAppear`. Deployment target 26 per
  ADR-0004, so no availability checks.
- Every component variant has a `#Preview` with fixture data on every
  platform it ships on. CI renders each one to a PNG per ADR-0007, so a
  variant without a preview is invisible to reviewers. A component that
  cannot be previewed without a screen is a screen.

The `swiftui-composition` skill holds the rules with before and after
examples. The `implement` skill reads it before writing a view; the
`impl-reviewer` checks diffs against it.

## Options considered

1. **One view per screen with flags and `#if os` inside.** The current
   shape. States multiply with each flag, previews need the whole screen,
   and reviewers cannot find DR-6 anatomy in one place.
2. **A view model class per component (MVVM).** A class per row kills
   previews and list performance, and the row does not own any state worth
   a class. Models belong to screens.
3. **Separate view trees per platform** in `Apps/TV` and `Apps/Mobile`.
   Three copies of the channel row drift apart. DR-6 wants one anatomy.
4. **Keep Vercel's rules as a skill only, no ADR.** A skill guides the
   writer. The folder split and the environment contract bind reviewers and
   the file layout, which is the hard-to-reverse part.

## Consequences

- Good: a component previews on its own with fixtures, so DR-6, DR-7 and
  DR-8 are checked in one file per part instead of per screen.
- Good: a board maps to one screen file, and a screen reads as a list of
  the parts the board shows.
- Bad: more files per part. A namespace enum, an `@Entry`, a provider and
  one file per variant where one struct used to do.
- Bad: the environment is unchecked at compile time. A sub-view rendered
  outside its provider gets the `@Entry` default and shows nothing wrong
  until someone looks. The preview per variant is the guard.
- Follow-ups: move `ChannelRow` out of `Views/` into `Components/` in the
  first implementing PR and fix it to DR-8 there. Add the skill to the
  `impl-reviewer` checklist.
