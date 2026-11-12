#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// What Settings asks of the file picker: a new source, or a new copy
    /// for an existing file source (local-m3u-file-import capability).
    struct FileImportAsk: Equatable {
        /// The file source Re-import was chosen on; nil adds a source.
        var replacing: ImportRequest.Target?
        /// A file dropped on the window, which skips the picker.
        var dropped: URL?
    }

    /// "Import a file" and Re-import in Sources and Settings: the picker,
    /// then the import sheet, then, for a one-link file, the add-source
    /// sheet on M3U with the link filled in.
    struct SettingsFileImport: ViewModifier {
        @Binding var ask: FileImportAsk?
        @State private var picking = false
        @State private var importing: ImportRequest?
        @State private var addLink: SourceFields?

        func body(content: Content) -> some View {
            content
                .onChange(of: ask) { _, new in
                    guard let new else { return }
                    if let url = new.dropped {
                        importing = ImportRequest(url: url, replacing: new.replacing)
                        ask = nil
                    } else {
                        picking = true
                    }
                }
                .playlistPicker(isPresented: $picking) { url in
                    importing = ImportRequest(url: url, replacing: ask?.replacing)
                    ask = nil
                }
                .onChange(of: picking) { _, shown in if !shown, importing == nil { ask = nil } }
                .sheet(item: $importing) { request in
                    ImportSheet(
                        request,
                        actions: .init(
                            finish: { _ in importing = nil },
                            addLink: { link in
                                importing = nil
                                addLink = SourceFields(kind: .m3u, url: link.absoluteString)
                            }))
                }
                .sheet(isPresented: Binding(get: { addLink != nil }, set: { if !$0 { addLink = nil } })) {
                    SettingsAddSource(fields: addLink)
                }
        }
    }
#endif
