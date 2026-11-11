import SwiftUI

extension Browse {
    /// The iPad and Mac sidebar (`iPad`, "Sidebar: sections + groups"): the
    /// Antenna mark, the sections, the Groups eyebrow with one row per
    /// group, and Sources & Settings at the bottom. 232 wide on the
    /// sidebar color.
    struct Sidebar<Sections: View, Groups: View, Footer: View>: View {
        /// The label over the groups: "Groups" on Live, "Genres" on Movies and Series.
        var eyebrow = "Groups"
        @ViewBuilder var sections: Sections
        @ViewBuilder var groups: Groups
        @ViewBuilder var footer: Footer

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .accessibilityHidden(true)
                    Text("Antenna")
                }
                .font(.title3.weight(.bold))
                .padding(EdgeInsets(top: 0, leading: 12, bottom: 18, trailing: 12))
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        sections
                        Eyebrow(text: eyebrow)
                            .padding(EdgeInsets(top: 22, leading: 12, bottom: 8, trailing: 12))
                        groups
                    }
                }
                .scrollIndicators(.hidden)
                footer
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 12)
            .frame(width: 232)
            .frame(maxHeight: .infinity, alignment: .top)
            .foregroundStyle(Palette.text)
            .background(Palette.tabBar.ignoresSafeArea())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("browse.sidebar")
        }
    }

    /// The 13 pt uppercase muted label over a group of rows.
    struct Eyebrow: View {
        let text: String

        var body: some View {
            Text(text.uppercased())
                .font(.footnote.weight(.semibold))
                .tracking(1)
                .foregroundStyle(Palette.textMuted)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// A section of the app in the sidebar; the open one is filled.
    struct SectionRow: View {
        let title: String
        let systemImage: String
        let isSelected: Bool
        let select: () -> Void

        var body: some View {
            Button(action: select) {
                Label(title, systemImage: systemImage)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .labelStyle(SidebarLabelStyle())
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                    .background(isSelected ? Palette.surface(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    /// A channel group with its count; the open one is filled.
    struct GroupRow: View {
        let title: String
        let systemImage: String?
        let count: Int
        let isSelected: Bool
        let select: () -> Void

        var body: some View {
            Button(action: select) {
                HStack {
                    HStack(spacing: 8) {
                        if let systemImage {
                            Image(systemName: systemImage).accessibilityHidden(true)
                        }
                        Text(title).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text(String(count))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Palette.textMuted)
                }
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                .background(isSelected ? Palette.surface(0.08) : .clear, in: RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    private struct SidebarLabelStyle: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 12) {
                configuration.icon.frame(width: 22)
                configuration.title
            }
        }
    }
}

#Preview("Sidebar", traits: .fixedLayout(width: 232, height: 834)) {
    Browse.Sidebar {
        Browse.SectionRow(title: "Live", systemImage: "tv", isSelected: true) {}
        Browse.SectionRow(title: "Guide", systemImage: "list.bullet.rectangle", isSelected: false) {}
        Browse.SectionRow(title: "Movies", systemImage: "film", isSelected: false) {}
        Browse.SectionRow(title: "Series", systemImage: "square.grid.2x2", isSelected: false) {}
        Browse.SectionRow(title: "Search", systemImage: "magnifyingglass", isSelected: false) {}
    } groups: {
        Browse.GroupRow(title: "Favorites", systemImage: "star", count: 12, isSelected: false) {}
        Browse.GroupRow(title: "All channels", systemImage: nil, count: 412, isSelected: false) {}
        Browse.GroupRow(title: "Sport", systemImage: nil, count: 42, isSelected: true) {}
        Browse.GroupRow(title: "News", systemImage: nil, count: 31, isSelected: false) {}
    } footer: {
        Browse.SectionRow(title: "Sources & Settings", systemImage: "gearshape", isSelected: false) {}
    }
}
