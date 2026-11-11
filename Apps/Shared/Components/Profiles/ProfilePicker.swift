import AntennaCore
import SwiftUI

/// The "Who's watching?" screen (profiles capability; `TV-Profiles`, `iPhone-Profiles`):
/// a title, one tile per profile with its color and initial, and a slot
/// under them for Manage profiles. Compiles on every platform so the
/// snapshot job renders its previews.
struct ProfilePicker<Footer: View>: View {
    let tiles: [ProfileTile]
    /// Which tile has focus, by profile id.
    let focus: FocusState<UUID?>.Binding
    let choose: (UUID) -> Void
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: Metrics.titleGap) {
            Spacer(minLength: 0)
            Text("Who's watching?")
                .font(.system(size: Metrics.title, weight: .bold))
            LazyVGrid(columns: columns, spacing: Metrics.rowGap) {
                ForEach(Array(zip(tiles.indices, tiles)), id: \.1.id) { index, tile in
                    Button {
                        choose(tile.id)
                    } label: {
                        ProfileTileLabel(tile: tile)
                    }
                    .buttonStyle(TileStyle())
                    .focused(focus, equals: tile.id)
                    .accessibilityLabel("\(tile.name), profile")
                    .accessibilityIdentifier("profiles.tile.\(index)")
                }
            }
            Spacer(minLength: 0)
            footer
                .padding(.bottom, Metrics.footerBottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.ground)
        .foregroundStyle(Palette.text)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profiles.picker")
    }

    /// One row on Apple TV, two columns on iPhone, iPad and Mac (`iPhone-Profiles`).
    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(Metrics.column), spacing: Metrics.tileGap), count: max(1, min(tiles.count, Metrics.columns)))
    }
}

private enum Metrics {
    #if os(tvOS)
        static let title: CGFloat = 56
        static let titleGap: CGFloat = 80
        static let tileGap: CGFloat = 80
        static let rowGap: CGFloat = 60
        static let column: CGFloat = 220
        static let columns = ProfileList.limit
        static let footerBottom: CGFloat = 120
    #else
        static let title: CGFloat = 28
        static let titleGap: CGFloat = 48
        static let tileGap: CGFloat = 40
        static let rowGap: CGFloat = 32
        static let column: CGFloat = 130
        static let columns = 2
        static let footerBottom: CGFloat = 60
    #endif
}

/// One profile on the picker.
struct ProfileTile: Identifiable, Equatable {
    let id: UUID
    let name: String
    let initial: String
    let color: UInt32
}

extension ProfileTile {
    init(_ profile: Profile) {
        self.init(id: profile.id, name: profile.name, initial: profile.initial, color: profile.color)
    }
}

/// A profile's color circle with its initial, and the name under it.
struct ProfileTileLabel: View {
    let tile: ProfileTile
    @Environment(\.isFocused) private var isFocused

    #if os(tvOS)
        private let size: CGFloat = 200
        private let initialSize: CGFloat = 88
        private let nameSize: CGFloat = 32
    #else
        private let size: CGFloat = 112
        private let initialSize: CGFloat = 48
        private let nameSize: CGFloat = 17
    #endif

    var body: some View {
        VStack(spacing: size / 9) {
            ZStack {
                Circle().fill(Color(hex: tile.color))
                Text(tile.initial)
                    .font(.system(size: initialSize, weight: .bold))
                    .foregroundStyle(Palette.ground)
            }
            .frame(width: size, height: size)
            .overlay(Circle().stroke(isFocused ? Palette.focus : .clear, lineWidth: 6).padding(-10))
            .scaleEffect(isFocused ? 1.08 : 1)
            .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 20, y: 18)
            Text(tile.name)
                .font(.system(size: nameSize, weight: isFocused ? .semibold : .regular))
                .foregroundStyle(isFocused ? Palette.text : ChannelOverlay.tileText)
                .lineLimit(1)
        }
    }
}

private struct TileStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension Color {
    /// A color from a 24-bit RGB value such as 0x5BB8FF.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

private struct PickerPreview: View {
    @FocusState private var focus: UUID?

    var body: some View {
        ProfilePicker(tiles: Self.tiles, focus: $focus, choose: { _ in }) {
            EmptyView()
        }
    }

    static let tiles: [ProfileTile] = [
        .init(id: Profile.mainID, name: "Dad", initial: "D", color: Profile.colors[0]),
        .init(id: UUID(uuid: (1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)), name: "Mum", initial: "M", color: Profile.colors[4]),
        .init(id: UUID(uuid: (2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)), name: "Kids", initial: "K", color: Profile.colors[5]),
    ]
}

#Preview("Who's watching, three profiles", traits: .fixedLayout(width: 1920, height: 1080)) {
    PickerPreview()
}
