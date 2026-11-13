import SwiftUI

/// The one layout for empty, unavailable and error states
/// (design-system/empty-and-error-states-share-one-layout): a symbol, a
/// title, a message and up to two actions, the first of which moves the user
/// forward. `ContentUnavailableView` sets the type for the platform, and the
/// actions take the system bordered style, so Apple TV gives them its own
/// focus. Boards `TV-Shell-Empty`, `iPhone-Live-Empty`, `TV-Player-Error`.
///
/// `identifier` names the whole state; its title is `<identifier>.title`.
/// The message lines and the buttons carry their own identifiers.
struct StatusView<Message: View, Actions: View>: View {
    let symbol: String
    let title: Text
    let identifier: String
    let message: Message
    let actions: Actions

    /// A title the catalog translates, such as "No channels yet".
    init(
        symbol: String, title: LocalizedStringResource, identifier: String,
        @ViewBuilder message: () -> Message, @ViewBuilder actions: () -> Actions
    ) {
        self.init(symbol: symbol, text: Text(title), identifier: identifier, message: message, actions: actions)
    }

    /// A title already in the user's language, such as a player error's.
    init(
        symbol: String, verbatimTitle title: String, identifier: String, @ViewBuilder message: () -> Message,
        @ViewBuilder actions: () -> Actions
    ) {
        self.init(symbol: symbol, text: Text(verbatim: title), identifier: identifier, message: message, actions: actions)
    }

    private init(symbol: String, text: Text, identifier: String, message: () -> Message, actions: () -> Actions) {
        self.symbol = symbol
        self.title = text
        self.identifier = identifier
        self.message = message()
        self.actions = actions()
    }

    var body: some View {
        ContentUnavailableView {
            Label {
                title
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("\(identifier).title")
            } icon: {
                Image(systemName: symbol)
                    .accessibilityHidden(true)
            }
        } description: {
            VStack(spacing: Metrics.Spacing.xSmall) { message }
        } actions: {
            HStack(spacing: Metrics.Spacing.medium) { actions }
                .buttonStyle(.bordered)
                .tint(StatusActions.tint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

/// The tint of a status's buttons. Apple TV keeps the system's gray
/// platter, since the accent tint fills an unfocused bordered button with
/// the same color as its label. Elsewhere the accent labels the buttons.
enum StatusActions {
    static var tint: Color? {
        #if os(tvOS)
            nil
        #else
            Palette.accent
        #endif
    }
}

extension StatusView where Message == StatusLines {
    /// A state whose message is plain lines, one per source or reason.
    init(
        symbol: String, title: LocalizedStringResource, lines: [LocalizedStringResource], identifier: String,
        @ViewBuilder actions: () -> Actions
    ) {
        self.init(symbol: symbol, title: title, identifier: identifier, message: { StatusLines(lines: lines) }, actions: actions)
    }
}

extension StatusView where Message == StatusLines {
    /// A state whose title and lines are already in the user's language,
    /// as AntennaCore words them.
    init(
        symbol: String, verbatimTitle title: String, verbatimLines lines: [String], identifier: String, @ViewBuilder actions: () -> Actions
    ) {
        self.init(
            symbol: symbol, verbatimTitle: title, identifier: identifier,
            message: { StatusLines(lines: lines.map(LocalizedStringResource.verbatim)) }, actions: actions)
    }
}

extension StatusView where Message == StatusLines, Actions == EmptyView {
    /// A state with nothing to do but wait or change what was asked.
    init(symbol: String, title: LocalizedStringResource, lines: [LocalizedStringResource], identifier: String) {
        self.init(symbol: symbol, title: title, identifier: identifier, message: { StatusLines(lines: lines) }, actions: { EmptyView() })
    }

    /// The same, with a title and lines already in the user's language.
    init(symbol: String, verbatimTitle title: String, verbatimLines lines: [String], identifier: String) {
        self.init(symbol: symbol, verbatimTitle: title, verbatimLines: lines, identifier: identifier, actions: { EmptyView() })
    }
}

/// The message of a `StatusView` as plain lines.
struct StatusLines: View {
    let lines: [LocalizedStringResource]

    var body: some View {
        ForEach(lines.indices, id: \.self) { index in
            Text(lines[index])
        }
    }
}

#Preview("No channels yet, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    StatusView(
        symbol: "antenna.radiowaves.left.and.right.slash", title: "No channels yet",
        lines: ["Home playlist: no channels", "Cabin: waiting for its login to sync from iCloud"], identifier: "shell.empty"
    ) {
        Button("Open Settings") {}
        Button("Try again") {}
    }
    .background(Palette.ground)
}

#Preview("No channels yet, iPhone", traits: .fixedLayout(width: 390, height: 700)) {
    StatusView(
        symbol: "antenna.radiowaves.left.and.right.slash", title: "No channels yet",
        lines: ["Cabin: waiting for its login to sync from iCloud"], identifier: "browse.empty"
    ) {
        Button("Open Settings") {}
        Button("Try again") {}
    }
    .background(Palette.ground)
}

#Preview("No results, iPhone", traits: .fixedLayout(width: 390, height: 400)) {
    StatusView(
        symbol: "magnifyingglass", title: "No results for “norhtern”",
        lines: ["Check the spelling or try a channel number."], identifier: "search.empty"
    )
    .background(Palette.ground)
}
