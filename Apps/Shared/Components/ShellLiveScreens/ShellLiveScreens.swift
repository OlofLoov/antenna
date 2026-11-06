import SwiftUI

/// What Live shows on Apple TV before a channel plays (spec 0015;
/// `TV-Shell-Loading`, `TV-Shell-Empty` and their `-Menu` boards). Compiles
/// on every platform so the snapshot job renders its previews.
enum ShellLoading {
    /// One source on the loading screen.
    struct Row: Identifiable, Equatable, Sendable {
        enum Indicator: Equatable, Sendable {
            /// Still loading: a 44 pt ring with the accent arc.
            case working
            /// Finished loading, with or without channels: an accent check (design-system/one-accent-color deviation in tvos-shell).
            case done
            /// Failed or waiting: the 44 pt slot stays empty so names line up.
            case none
        }

        var id: UUID
        var name: String
        var detail: String
        var indicator: Indicator
        /// Read by UI tests and VoiceOver: `loading`, `loaded:<n>`, `offline`, `failed`, `waitingForLogin`.
        var value: String
    }

    /// One row per source, name 26 pt and detail 22 pt muted, on a
    /// 1000 wide 0.06 panel.
    struct Screen: View {
        let rows: [Row]

        var body: some View {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    RowView(row: row)
                    if row.id != rows.last?.id {
                        Rectangle().fill(Palette.surface(0.08)).frame(height: 1)
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .frame(width: 1000)
            .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 20))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    struct RowView: View {
        let row: Row

        var body: some View {
            HStack(spacing: 24) {
                switch row.indicator {
                case .working:
                    Spinner()
                case .done:
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Palette.ground)
                        .frame(width: 44, height: 44)
                        .background(Palette.accent, in: Circle())
                case .none:
                    Color.clear.frame(width: 44, height: 44)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.name)
                        .font(.system(size: 26))
                        .foregroundStyle(Palette.text)
                    Text(row.detail)
                        .font(.system(size: 22))
                        .foregroundStyle(Palette.textMuted)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 96)
            .accessibilityElement(children: .combine)
            .accessibilityValue(row.value)
            .accessibilityIdentifier("shell.loading.\(row.id.uuidString)")
        }
    }
}

/// The board's indeterminate ring: 4 pt at 0.18 white with an accent arc
/// that turns.
private struct Spinner: View {
    @State private var turning = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(Palette.surface(0.18), lineWidth: 4)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(Palette.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(turning ? 360 : 0))
        }
        .padding(2)
        .frame(width: 44, height: 44)
        .onChange(of: reduceMotion, initial: true) { _, reduce in
            guard !reduce else { return }
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { turning = true }
        }
    }
}

/// "No channels yet" with a line per source that added nothing and Retry.
enum ShellEmpty {
    struct Line: Identifiable, Equatable, Sendable {
        var id: UUID
        var text: String
        /// Read by UI tests: `loaded:0`, `offline`, `failed`, `waitingForLogin`.
        var value: String
    }

    struct Screen<Retry: View>: View {
        let lines: [Line]
        @ViewBuilder var retry: Retry

        var body: some View {
            VStack(spacing: 14) {
                Text("No channels yet")
                    .font(.system(size: 29, weight: .bold))
                    .foregroundStyle(Palette.text)
                ForEach(lines) { line in
                    Text(line.text)
                        .font(.system(size: 24))
                        .foregroundStyle(Palette.textMuted)
                        .accessibilityValue(line.value)
                        .accessibilityIdentifier("shell.empty.source.\(line.id.uuidString)")
                }
                retry
                    .padding(.top, 26)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("shell.empty")
        }
    }

    /// 26 pt bold, radius 14. The Focus token while focused, the 0.12
    /// surface while the tab bar has focus.
    struct RetryButton: View {
        let retry: () -> Void

        var body: some View {
            Button("Retry", action: retry)
                .buttonStyle(RetryStyle())
        }
    }

    private struct RetryStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            RetryLabel(label: configuration.label)
        }
    }

    private struct RetryLabel<Label: View>: View {
        let label: Label
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            label
                .font(.system(size: 26, weight: .bold))
                .padding(.vertical, 18)
                .padding(.horizontal, 44)
                .foregroundStyle(isFocused ? Palette.ground : Palette.text)
                .background(isFocused ? Palette.focus : Palette.surface(0.12), in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
        }
    }
}

#Preview("Loading, one source working and one empty", traits: .fixedLayout(width: 1920, height: 1080)) {
    ShellLoading.Screen(rows: [
        .init(id: UUID(), name: "Home provider", detail: "Loading channels", indicator: .working, value: "loading"),
        .init(id: UUID(), name: "Cabin", detail: "0 channels", indicator: .none, value: "loaded:0"),
    ])
    .background(Palette.ground)
}

#Preview("Loading, one source done", traits: .fixedLayout(width: 1920, height: 1080)) {
    ShellLoading.Screen(rows: [
        .init(id: UUID(), name: "Home provider", detail: "412 channels", indicator: .done, value: "loaded:412"),
        .init(id: UUID(), name: "Cabin", detail: "Waiting for its login to sync from iCloud", indicator: .none, value: "waitingForLogin"),
    ])
    .background(Palette.ground)
}

#Preview("No channels yet", traits: .fixedLayout(width: 1920, height: 1080)) {
    ShellEmpty.Screen(lines: [
        .init(id: UUID(), text: "Home provider: waiting for its login to sync from iCloud", value: "waitingForLogin"),
        .init(id: UUID(), text: "Cabin: no channels", value: "loaded:0"),
    ]) {
        ShellEmpty.RetryButton {}
    }
    .background(Palette.ground)
}
