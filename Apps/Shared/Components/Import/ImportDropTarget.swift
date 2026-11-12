#if os(iOS) || os(macOS)
    import SwiftUI

    /// `import.dropTarget` (`iPad-Import`): the ring over the window while a
    /// playlist file is dragged over it. Values only.
    struct ImportDropTarget: View {
        /// The dragged file's name, nil when the item has none.
        let fileName: String?

        static func title(fileName: String?) -> String {
            fileName.map { "Drop to import \($0)" } ?? "Drop to import a playlist"
        }

        var body: some View {
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 34))
                    .foregroundStyle(Palette.text)
                    .accessibilityHidden(true)
                Text(Self.title(fileName: fileName))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .multilineTextAlignment(.center)
                Text("M3U, M3U8 and text files, up to 16 MB")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.textMuted)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.surface(0.08), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.text, style: StrokeStyle(lineWidth: 2, dash: [8, 6])))
            .padding(16)
            .background(Palette.ground.opacity(0.7))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("import.dropTarget")
        }
    }

    #Preview("Drop target, named file") {
        ImportDropTarget(fileName: "nordic-extra.m3u")
            .preferredColorScheme(.dark)
    }

    #Preview("Drop target, no name") {
        ImportDropTarget(fileName: nil)
            .preferredColorScheme(.dark)
    }
#endif
