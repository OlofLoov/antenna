#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// The pieces of the import sheet (`iPhone-Import`, `iPhone-Import-TooLarge`,
    /// `iPhone-Import-Malformed`). Values and closures only.
    enum ImportSheetParts {
        static let body = Color(red: 0xD7 / 255, green: 0xDE / 255, blue: 0xE8 / 255)
        static let fileTile = Color(red: 0x26 / 255, green: 0x34 / 255, blue: 0x4A / 255)

        /// `import.file`: the file's name and size, with `detail` beneath
        /// while the file is read.
        struct FileCard<Detail: View>: View {
            let fileName: String
            let size: String?
            @ViewBuilder var detail: Detail

            var body: some View {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 22))
                            .foregroundStyle(ImportSheetParts.body)
                            .frame(width: 44, height: 44)
                            .background(ImportSheetParts.fileTile, in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fileName)
                                .font(.system(size: 16, weight: .semibold))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if let size {
                                Text(size).font(.system(size: 13)).foregroundStyle(Palette.textMuted)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    detail
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("import.file")
            }
        }

        /// `import.progress`: the 26 pt ring and "Reading <file>…".
        struct Reading: View {
            let fileName: String

            var body: some View {
                HStack(spacing: 12) {
                    ProgressView()
                        .frame(width: 26, height: 26)
                    Text("Reading \(fileName)…")
                        .font(.system(size: 16))
                        .foregroundStyle(ImportSheetParts.body)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("import.progress")
            }
        }

        /// `import.summary`: channels and groups, the guide link, the skipped entries.
        struct Summary: View {
            let summary: ImportText.Summary

            var body: some View {
                VStack(spacing: 0) {
                    row(title: summary.channels, detail: summary.groups, mark: .check, id: "import.summary.channels")
                    if let host = summary.guideHost {
                        Divider().overlay(Palette.surface(0.08))
                        row(title: "Guide link found", detail: host, mark: .check, id: "import.summary.guide")
                    }
                    if let skipped = summary.skipped {
                        Divider().overlay(Palette.surface(0.08))
                        row(title: skipped, detail: "Not links", mark: .count(skipped.prefix { $0 != " " }), id: "import.summary.skipped")
                    }
                }
                .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("import.summary")
            }

            private enum Mark {
                case check
                case count(Substring)
            }

            private func row(title: String, detail: String?, mark: Mark, id: String) -> some View {
                HStack(spacing: 12) {
                    Group {
                        switch mark {
                        case .check:
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(Palette.ground)
                                .frame(width: 26, height: 26)
                                .background(Palette.accent, in: Circle())
                        case .count(let number):
                            Text(number)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Palette.textMuted)
                                .frame(width: 26, height: 26)
                                .overlay(Circle().stroke(Palette.textMuted, lineWidth: 1.5))
                        }
                    }
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.system(size: 16)).lineLimit(1)
                        if let detail {
                            Text(detail).font(.system(size: 13)).foregroundStyle(Palette.textMuted).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 60)
                .padding(.horizontal, 14)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(id)
            }
        }

        /// `import.error`: why the file cannot be imported.
        struct Problem: View {
            let problem: ImportText.Problem

            var body: some View {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(OnboardingForm.errorColor)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(problem.title).font(.system(size: 16, weight: .semibold))
                        if let body = problem.body {
                            Text(body).font(.system(size: 15)).foregroundStyle(ImportSheetParts.body)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("import.error")
            }
        }

        /// "You imported <file> before as <name>".
        struct ImportedBefore: View {
            let text: String

            var body: some View {
                Label(text, systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 15))
                    .foregroundStyle(ImportSheetParts.body)
                    .padding(.horizontal, 4)
                    .accessibilityIdentifier("import.importedBefore")
            }
        }

        /// The Source group: Name, when the sheet adds a source, and Guide URL.
        struct Fields: View {
            let name: Binding<String>?
            @Binding var guideLink: String

            var body: some View {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Source")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.textMuted)
                        .padding(.horizontal, 4)
                    VStack(spacing: 0) {
                        if let name {
                            field("Name", text: name, id: "import.field.name")
                            Divider().overlay(Palette.surface(0.08))
                        }
                        field("Guide URL", text: $guideLink, id: "import.field.guideURL")
                    }
                    .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 12))
                    Label(
                        "Antenna keeps a copy of this file and syncs it through iCloud, Apple TV included. "
                            + "Changes to the file are not picked up; re-import to update.",
                        systemImage: "icloud"
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textMuted)
                    .padding(.horizontal, 4)
                }
            }

            private func field(_ label: String, text: Binding<String>, id: String) -> some View {
                HStack(spacing: 12) {
                    Text(label).font(.system(size: 16)).foregroundStyle(ImportSheetParts.body).frame(width: 88, alignment: .leading)
                    TextField("Optional", text: text)
                        .font(.system(size: 16))
                        .autocorrectionDisabled()
                        #if os(iOS)
                            .textInputAutocapitalization(.never)
                        #endif
                        .accessibilityIdentifier(id)
                }
                .frame(minHeight: 48)
                .padding(.horizontal, 14)
            }
        }

        /// The white button: Import, Replace or "Replace <name>". Dimmed
        /// to the surface while disabled, as when the file is read or refused.
        struct Primary: View {
            let title: String
            let id: String
            let action: () -> Void
            @Environment(\.isEnabled) private var isEnabled

            var body: some View {
                Button(action: action) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(isEnabled ? Palette.ground : Palette.textMuted)
                        .background(isEnabled ? Palette.text : Palette.surface(0.12), in: RoundedRectangle(cornerRadius: 14))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(id)
            }
        }

        /// The surface button under a white one: "Import as new".
        struct Secondary: View {
            let title: String
            let id: String
            let action: () -> Void

            var body: some View {
                Button(action: action) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(Palette.text)
                        .background(Palette.surface(0.12), in: RoundedRectangle(cornerRadius: 14))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(id)
            }
        }

        /// An accent text button: "Choose another file", "Add the link as a source".
        struct Quiet: View {
            let title: String
            let id: String
            let action: () -> Void

            var body: some View {
                Button(title, action: action)
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(id)
            }
        }
    }

    #Preview("Import parts, inspected") {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ImportSheetParts.FileCard(fileName: "home-playlist.m3u", size: "2.4 MB") { EmptyView() }
                ImportSheetParts.Summary(
                    summary: .init(
                        channels: "412 channels in 18 groups",
                        groups: "Sport, News, Kids, Movies, Documentary, Music, Series, Sweden and 10 more",
                        guideHost: "epg.example-provider.net", skipped: "3 entries skipped"))
                ImportSheetParts.ImportedBefore(text: "You imported home-playlist.m3u before as Home")
                ImportSheetParts.Fields(
                    name: .constant("home-playlist"), guideLink: .constant("http://epg.example-provider.net/guide.xml.gz"))
                ImportSheetParts.Primary(title: "Replace Home", id: "import.replace") {}
                ImportSheetParts.Secondary(title: "Import as new", id: "import.import") {}
            }
            .padding(16)
        }
        .foregroundStyle(Palette.text)
        .background(Palette.ground)
        .preferredColorScheme(.dark)
    }

    #Preview("Import parts, refused") {
        VStack(alignment: .leading, spacing: 22) {
            ImportSheetParts.FileCard(fileName: "everything.m3u", size: "41.7 MB") { EmptyView() }
            ImportSheetParts.Problem(
                problem: .init(
                    title: "This file is 41.7 MB. Antenna imports playlists up to 16 MB.",
                    body: "Split the file, or host it and add the link as an M3U source instead."))
            ImportSheetParts.FileCard(fileName: "channels.m3u", size: nil) { ImportSheetParts.Reading(fileName: "channels.m3u") }
            ImportSheetParts.Primary(title: "Import", id: "import.import") {}.disabled(true)
            ImportSheetParts.Quiet(title: "Choose another file", id: "import.pickFile") {}
        }
        .padding(16)
        .foregroundStyle(Palette.text)
        .background(Palette.ground)
        .preferredColorScheme(.dark)
    }
#endif
