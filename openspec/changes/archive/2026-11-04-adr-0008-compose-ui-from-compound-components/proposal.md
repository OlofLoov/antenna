# Proposal: compose UI from compound components with state injected through the environment (adr-0008)

## Why

Recorded as Proposed; the owner has not accepted it yet.

One app has three layouts. The design system draws the same parts on every
platform (channel row, programme progress bar, badges, section header,
content card) inside layouts that differ completely between tvOS, iPad and
Mac, and iPhone. Every board in `openspec/specs/design-system/boards/` is
waiting for code.

The two views that exist already show where this goes without a rule.
`ChannelsView` owns the SwiftData query, the loading model, the list and the
navigation in one body. `ChannelRow` draws a system glyph when the logo is
missing, which the design-system requirement "Channels without a logo show
initials" forbids, and the fix will be tempting to make with a
`showsInitials: Bool` parameter. A few more screens like this and every
shared view carries `isTV`, `compact` and `showsProgress` flags, each
doubling the states a reviewer has to check against the board.

Vercel's `composition-patterns` skill solves this problem for React with
eight rules: no boolean prop sprawl, compound components, state lifted into a
provider, a generic context contract, explicit variants, children over render
props. SwiftUI has the same primitives under other names. The environment is
context, `@ViewBuilder` closures are children, and `@Observable` plus
`@Entry` are the modern APIs. The rules translate almost one to one.

## What Changes

- Shared UI is built from three kinds of view, each in its own place under
  `Apps/Shared/`, so a reviewer can tell the kind from the folder:
  components in `Components/`, screens in `Views/`, and the shell
  (`RootView`, `Apps/Mobile`, `Apps/TV`).
- No `Bool` initializer parameter chooses a layout. A different arrangement
  of parts is a differently named view.
- State or actions shared by more than one sub-view live in one environment
  value declared with `@Entry`, provided only by the screen.
- Composition uses `@ViewBuilder` closures. No `AnyView` parameters, no
  `header: some View` parameters, no `showsFooter` flags.
- Current APIs only: `@Observable`, `@Environment(Model.self)`, `@Entry` and
  `.task`.
- Every component variant has a `#Preview` with fixture data on every
  platform it ships on.
- The `swiftui-composition` skill holds the rules with before and after
  examples. The `implement` skill reads it before writing a view, and the
  `impl-reviewer` checks diffs against it.

## Capabilities

### New Capabilities

None. This is an architecture decision with no requirement of its own.

### Modified Capabilities

None.

## Impact

- A component previews on its own with fixtures, so the design-system
  requirements "Channel rows share one anatomy", "A current programme always
  shows its progress" and "Channels without a logo show initials" are checked
  in one file per part instead of per screen.
- A board maps to one screen file, and a screen reads as a list of the parts
  the board shows.
- More files per part: a namespace enum, an `@Entry`, a provider and one file
  per variant where one struct used to do.
- The environment is unchecked at compile time. A sub-view rendered outside
  its provider gets the `@Entry` default and shows nothing wrong until
  someone looks. The preview per variant is the guard.
- Related at the time: the changes `add-first-run-onboarding`,
  `add-tv-channel-overlay`, `add-tv-zap-bar-and-number-entry`,
  `add-tv-guide-grid`, `add-live-tv-on-iphone-ipad-mac`,
  `add-movies-and-series-browsing` and `add-search`, and the `tvos-shell`
  capability.
- Follow-ups: move `ChannelRow` out of `Views/` into `Components/` in the
  first implementing PR and fix its logo fallback there. Add the skill to
  the `impl-reviewer` checklist.
