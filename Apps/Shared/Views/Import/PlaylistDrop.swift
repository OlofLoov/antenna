#if os(iOS) || os(macOS)
    import SwiftUI
    import UniformTypeIdentifiers

    /// Which dragged items the window takes (local-m3u-file-import/drop-a-file-on-the-window):
    /// a file that is an M3U playlist or plain text, or a file whose name
    /// ends in m3u, m3u8 or txt. Images, text snippets and web links are not files and show nothing.
    enum PlaylistDropRule {
        static let extensions: Set<String> = ["m3u", "m3u8", "txt"]

        /// One dragged item, as its provider describes it.
        struct Item: Equatable {
            var types: [String]
            /// The file name the source app suggests; text snippets and links have none.
            var suggestedName: String?
        }

        static func accepts(_ item: Item) -> Bool {
            let types = item.types.compactMap(UTType.init)
            if types.contains(where: { $0.conforms(to: .image) }) { return false }
            if types.contains(.url), !types.contains(.fileURL) { return false }
            if let name = item.suggestedName, extensions.contains((name as NSString).pathExtension.lowercased()) { return true }
            guard item.suggestedName != nil || types.contains(.fileURL) else { return false }
            return types.contains { $0.conforms(to: .m3uPlaylist) || $0.conforms(to: .plainText) }
        }

        /// The index of the first item the window takes, in drop order.
        static func first(_ items: [Item]) -> Int? {
            items.firstIndex(where: accepts)
        }
    }

    extension PlaylistDropRule.Item {
        init(_ provider: NSItemProvider) {
            self.init(types: provider.registeredTypeIdentifiers, suggestedName: provider.suggestedName)
        }
    }

    extension View {
        /// Shows `import.dropTarget` while a playlist file is dragged over
        /// the view, and hands the first one dropped to `open`, copied to a
        /// file of Antenna's own.
        func playlistDropTarget(open: @escaping @MainActor (URL) -> Void) -> some View {
            modifier(PlaylistDropModifier(open: open))
        }
    }

    private struct PlaylistDropModifier: ViewModifier {
        let open: @MainActor (URL) -> Void
        @State private var hovering: String??

        func body(content: Content) -> some View {
            content
                .overlay {
                    if let name = hovering {
                        ImportDropTarget(fileName: name)
                            .onTapGesture { debugDrop() }
                    }
                }
                .onDrop(of: [.item], delegate: Delegate(hovering: $hovering, open: open))
                #if DEBUG
                    .task {
                        if let provider = UITestingImport.draggedItem(), PlaylistDropRule.accepts(.init(provider)) {
                            hovering = .some(provider.suggestedName)
                        }
                    }
                #endif
        }

        /// A UI test taps the target to drop the scripted item.
        private func debugDrop() {
            #if DEBUG
                guard let provider = UITestingImport.draggedItem() else { return }
                hovering = nil
                Delegate.load(provider, open: open)
            #endif
        }

        struct Delegate: DropDelegate {
            @Binding var hovering: String??
            let open: @MainActor (URL) -> Void

            func validateDrop(info: DropInfo) -> Bool {
                info.itemProviders(for: [.item]).map(PlaylistDropRule.Item.init).contains(where: PlaylistDropRule.accepts)
            }

            func dropEntered(info: DropInfo) {
                let providers = info.itemProviders(for: [.item])
                guard let index = PlaylistDropRule.first(providers.map(PlaylistDropRule.Item.init)) else { return }
                hovering = .some(providers[index].suggestedName)
            }

            func dropExited(info: DropInfo) {
                hovering = nil
            }

            func performDrop(info: DropInfo) -> Bool {
                hovering = nil
                let providers = info.itemProviders(for: [.item])
                guard let index = PlaylistDropRule.first(providers.map(PlaylistDropRule.Item.init)) else { return false }
                Self.load(providers[index], open: open)
                return true
            }

            /// Copies the dropped file into the temporary folder, since the
            /// provider's copy goes when its handler returns, then opens it.
            static func load(_ provider: NSItemProvider, open: @escaping @MainActor (URL) -> Void) {
                let suggested = provider.suggestedName
                let type = provider.registeredTypeIdentifiers.first { UTType($0)?.conforms(to: .data) == true } ?? UTType.data.identifier
                _ = provider.loadFileRepresentation(forTypeIdentifier: type) { url, _ in
                    guard let url else { return }
                    let folder = FileManager.default.temporaryDirectory.appending(path: "dropped-\(UUID().uuidString)")
                    let copy = folder.appending(
                        path: suggested.map { name in
                            (name as NSString).pathExtension.isEmpty ? name + "." + url.pathExtension : name
                        } ?? url.lastPathComponent)
                    do {
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        try FileManager.default.copyItem(at: url, to: copy)
                    } catch {
                        return
                    }
                    Task { @MainActor in open(copy) }
                }
            }
        }
    }
#endif
