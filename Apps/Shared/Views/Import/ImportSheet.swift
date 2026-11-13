#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftData
    import SwiftUI
    import UniformTypeIdentifiers

    /// The import sheet (local-m3u-file-import capability; `iPhone-Import`,
    /// `iPhone-Import-TooLarge`, `iPhone-Import-Malformed`). One sheet for
    /// every way in: it reads the file, shows what it holds or why it cannot
    /// be imported, and saves it. iPadOS and macOS show it centered.
    struct ImportSheet: View {
        /// What the owner does once the sheet is done.
        struct Actions {
            /// Closes the sheet; given what was saved, nil when cancelled.
            var finish: (ImportModel.Saved?) -> Void
            /// "Add the link as a source": closes the sheet and opens the add-source form on M3U with the link.
            var addLink: (URL) -> Void
        }

        let actions: Actions
        @State private var model: ImportModel
        @State private var picking = false
        @Environment(\.modelContext) private var context
        @Environment(\.importInbox) private var inbox

        init(_ request: ImportRequest, actions: Actions) {
            self.actions = actions
            _model = State(initialValue: ImportModel(request))
        }

        var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    ScrollView {
                        content
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    buttons
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                }
                .foregroundStyle(Palette.text)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.ground)
                .navigationTitle(model.request.replacing.map { "Re-import \($0.name)" } ?? "Import a playlist")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            model.cancel()
                            actions.finish(nil)
                        }
                        .accessibilityIdentifier("import.cancel")
                    }
                }
            }
            .accessibilityIdentifier("import.sheet")
            .playlistPicker(isPresented: $picking) { url in
                model = ImportModel(ImportRequest(url: url, replacing: model.request.replacing))
            }
            .task(id: model.request.id) { await model.read(in: context) }
            .onAppear { inbox?.sheetOpened() }
            .onDisappear { inbox?.sheetClosed() }
        }

        @ViewBuilder private var content: some View {
            VStack(alignment: .leading, spacing: 22) {
                switch model.phase {
                case .reading:
                    ImportSheetParts.FileCard(fileName: model.fileName, size: model.sizeText) {
                        ImportSheetParts.Reading(fileName: model.fileName)
                    }
                case .inspected(_, let summary):
                    ImportSheetParts.FileCard(fileName: model.fileName, size: model.sizeText) { EmptyView() }
                    ImportSheetParts.Summary(summary: summary)
                    if let earlier = model.earlier {
                        ImportSheetParts.ImportedBefore(text: ImportText.importedBefore(fileName: model.fileName, name: earlier.name))
                    }
                    ImportSheetParts.Fields(name: model.request.replacing == nil ? $model.name : nil, guideLink: $model.guideLink)
                    if let error = model.saveError {
                        Text(error).font(.system(size: 15)).foregroundStyle(OnboardingForm.errorColor)
                    }
                case .refused(let problem, _):
                    ImportSheetParts.FileCard(fileName: model.fileName, size: model.sizeText) { EmptyView() }
                    ImportSheetParts.Problem(problem: problem)
                }
            }
        }

        @ViewBuilder private var buttons: some View {
            VStack(spacing: 10) {
                switch model.phase {
                case .reading:
                    ImportSheetParts.Primary(title: "Import", id: "import.import") {}.disabled(true)
                case .inspected:
                    if let target = model.request.replacing {
                        ImportSheetParts.Primary(title: "Replace", id: "import.import") { save(replacing: target.id) }
                    } else if let earlier = model.earlier {
                        ImportSheetParts.Primary(title: "Replace \(earlier.name)", id: "import.replace") { save(replacing: earlier.id) }
                        ImportSheetParts.Secondary(title: "Import as new", id: "import.import") { save(replacing: nil) }
                    } else {
                        ImportSheetParts.Primary(title: "Import", id: "import.import") { save(replacing: nil) }
                    }
                case .refused(_, let link):
                    ImportSheetParts.Primary(title: "Import", id: "import.import") {}.disabled(true)
                    if let link {
                        ImportSheetParts.Quiet(title: "Add the link as a source", id: "import.addAsURL") { actions.addLink(link) }
                    } else {
                        ImportSheetParts.Quiet(title: "Choose another file", id: "import.pickFile") { picking = true }
                    }
                }
            }
        }

        private func save(replacing target: UUID?) {
            if let saved = model.save(replacing: target, credentials: FileImport.appCredentials, into: context) {
                actions.finish(saved)
            }
        }
    }

    // MARK: Picker

    extension View {
        /// The system picker for a playlist or text file. In a Debug build
        /// launched with `-ui-testing-import-file`, each request is answered
        /// with the next fixture instead, through the same `onPick`.
        func playlistPicker(isPresented: Binding<Bool>, onPick: @escaping (URL) -> Void) -> some View {
            modifier(PlaylistPicker(isPresented: isPresented, onPick: onPick))
        }
    }

    private struct PlaylistPicker: ViewModifier {
        @Binding var isPresented: Bool
        let onPick: (URL) -> Void

        static let types: [UTType] =
            [.m3uPlaylist, .plainText, .text] + ["m3u", "m3u8", "txt"].compactMap { UTType(filenameExtension: $0) }

        func body(content: Content) -> some View {
            #if DEBUG
                if UITestingImport.replacesPicker {
                    content.onChange(of: isPresented) { _, shown in
                        guard shown else { return }
                        isPresented = false
                        if let url = UITestingImport.nextPick() { onPick(url) }
                    }
                } else {
                    picker(content)
                }
            #else
                picker(content)
            #endif
        }

        private func picker(_ content: Content) -> some View {
            content.fileImporter(isPresented: $isPresented, allowedContentTypes: Self.types) { result in
                if case .success(let url) = result { onPick(url) }
            }
        }
    }

    // MARK: Inbox

    /// Files shared to Antenna, opened with it from Finder or Files, wait
    /// here until a screen can show the import sheet
    /// (local-m3u-file-import/bring-a-file-in). A file that arrives while a
    /// sheet is open or another file waits is ignored.
    @MainActor @Observable
    final class ImportInbox {
        private(set) var pending: ImportRequest?
        @ObservationIgnored private var openSheets = 0

        func receive(_ url: URL) {
            guard url.isFileURL, pending == nil, openSheets == 0 else { return }
            pending = ImportRequest(url: url)
        }

        func take() {
            pending = nil
        }

        func sheetOpened() { openSheets += 1 }
        func sheetClosed() { openSheets = max(0, openSheets - 1) }
    }

    extension EnvironmentValues {
        /// The app's inbox for shared files. Nil in previews.
        @Entry var importInbox: ImportInbox?
    }
#endif
