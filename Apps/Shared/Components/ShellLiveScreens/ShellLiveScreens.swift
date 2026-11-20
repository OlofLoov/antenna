import AntennaCore
import SwiftUI

/// What Live shows on Apple TV before a channel plays (tvos-shell capability;
/// `TV-Shell-Loading`, `TV-Shell-Empty` and their `-Menu` boards). Compiles
/// on every platform so the snapshot job renders its previews.
enum ShellLoading {
    /// One source on the loading screen.
    struct Row: Identifiable, Equatable, Sendable {
        enum Indicator: Equatable, Sendable {
            /// Still loading: a 44 pt ring with the accent arc.
            case working
            /// Finished loading, with or without channels: an accent check (design-system/one-accent-color-per-profile deviation in tvos-shell).
            case done
            /// Failed or waiting: the 44 pt slot stays empty so names line up.
            case none
        }

        var id: UUID
        var name: String
        var detail: LocalizedStringResource
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
            .background(Palette.surface(0.06), in: cornerShape(.large))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    struct RowView: View {
        @Environment(\.accent) private var accent
        let row: Row

        var body: some View {
            HStack(spacing: 24) {
                switch row.indicator {
                case .working:
                    Spinner()
                case .done:
                    Image(systemName: "checkmark")
                        .font(.boardStyle(22, weight: .bold))
                        .foregroundStyle(Palette.ground)
                        .frame(width: 44, height: 44)
                        .background(accent.color, in: Circle())
                case .none:
                    Color.clear.frame(width: 44, height: 44)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.name)
                        .font(.boardStyle(26))
                        .foregroundStyle(Palette.text)
                    Text(row.detail)
                        .font(.boardStyle(22))
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
    @Environment(\.accent) private var accent
    @State private var turning = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(Palette.surface(0.18), lineWidth: 4)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(accent.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
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

/// "No channels yet" on the shared `StatusView` layout, with a line per
/// source that added nothing and the actions the screen passes.
enum ShellEmpty {
    struct Line: Identifiable, Equatable, Sendable {
        var id: UUID
        var text: LocalizedStringResource
        /// Read by UI tests: `loaded:0`, `offline`, `failed`, `waitingForLogin`.
        var value: String
    }

    /// Each line with `shell.empty.source.<id>`.
    struct Lines: View {
        let lines: [Line]

        var body: some View {
            ForEach(lines) { line in
                Text(line.text)
                    .accessibilityValue(line.value)
                    .accessibilityIdentifier("shell.empty.source.\(line.id.uuidString)")
            }
        }
    }

    /// Open Settings first, then Try again (`TV-Shell-Empty`).
    struct Screen<Actions: View>: View {
        let lines: [Line]
        @ViewBuilder var actions: Actions

        var body: some View {
            StatusView(symbol: "antenna.radiowaves.left.and.right.slash", title: "No channels yet", identifier: "shell.empty") {
                Lines(lines: lines)
            } actions: {
                actions
            }
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
        Button("Open Settings") {}
        Button("Try again") {}
    }
    .background(Palette.ground)
}
