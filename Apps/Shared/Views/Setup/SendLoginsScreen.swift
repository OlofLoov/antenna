#if !os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// "Sign in your Apple TV", opened by a sign-in code from an Apple TV
    /// (apple-tv-login-from-iphone/the-iphone-asks-before-it-sends). Lists the
    /// sources the TV asked for, takes a login this device lacks, sends the
    /// ready ones on Send and follows the pickup. iPad and Mac center it at
    /// 390 points. While sending it cannot be swiped away.
    struct SendLoginsScreen: View {
        let link: SetupLink
        /// Send: the code counts as used in this launch.
        let use: (SetupLink) -> Void
        /// Closes the sheet.
        let close: () -> Void
        @Environment(\.modelContext) private var context
        @Query(sort: SourceRecord.displayOrder) private var records: [SourceRecord]
        @State private var model: SendLoginsModel?
        @State private var entering: SendLoginsModel.Row?

        var body: some View {
            NavigationStack {
                ScrollView {
                    if let model {
                        SendLogins.Content(
                            device: SetupDevice.name, rows: rows(model), missing: model.missing, status: status(model)
                        ) { id in
                            entering = model.rows.first { $0.id == id }
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: 390)
                        .frame(maxWidth: .infinity)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if let model { bottom(model).padding(.horizontal, 16).padding(.bottom, 12).frame(maxWidth: 390) }
                }
                .background(Palette.ground)
                .navigationTitle("Sign in Apple TV")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    if model?.delivery == nil {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel", action: close).accessibilityIdentifier("sendLogins.cancel")
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
            .foregroundStyle(Palette.text)
            .interactiveDismissDisabled(sending)
            .accessibilityIdentifier("sendLogins")
            .task {
                if model == nil { model = SendLoginsModel(link: link, dependencies: .app) }
                model?.update(records.compactMap(\.descriptor))
            }
            .onChange(of: records.compactMap(\.descriptor)) { _, sources in
                model?.update(sources)
            }
            .task(id: model?.delivery.map(ObjectIdentifier.init)) {
                await model?.delivery?.run()
            }
            .sheet(item: $entering) { row in
                if let model {
                    SendLoginsEnter(row: row, model: model) { entering = nil }
                }
            }
        }

        private var sending: Bool {
            switch model?.delivery?.state {
            case .sending, .waiting: true
            default: false
            }
        }

        private func rows(_ model: SendLoginsModel) -> [SendLogins.Row] {
            model.rows.map { row in
                let state: SendLogins.Row.State =
                    switch model.delivery?.state {
                    case nil, .offline, .notSignedIn, .storageFull, .alreadyUsed, .failed: row.ready ? .ready : .notHere
                    case .sending, .waiting, .notPickedUp: row.ready ? .sending : .notHere
                    case .pickedUp: row.ready ? .sent : .notHere
                    }
                return SendLogins.Row(id: row.id, name: row.source.name, kind: row.source.kind, state: state)
            }
        }

        private func status(_ model: SendLoginsModel) -> SendLogins.Status? {
            let device = SetupDevice.name
            switch model.delivery?.state {
            case nil: return nil
            case .sending, .waiting: return .sending
            case .pickedUp: return .pickedUp
            case .notPickedUp: return .notPickedUp
            case .offline, .failed: return .problem("Couldn't send. Check that this \(device) is online, then try again.")
            case .notSignedIn:
                return .problem(
                    "This \(device) isn't signed in to iCloud, so it can't send logins to your Apple TV. "
                        + "Sign in to iCloud in Settings, then scan the code again.")
            case .storageFull: return .problem("Couldn't send because your iCloud storage is full.")
            case .alreadyUsed: return .problem("This code was already used. If the Apple TV still needs a login, it shows a new code.")
            }
        }

        @ViewBuilder private func bottom(_ model: SendLoginsModel) -> some View {
            switch model.delivery?.state {
            case nil where model.hasNone, .pickedUp, .notPickedUp, .storageFull, .alreadyUsed:
                SendLogins.Primary(title: "Done", identifier: "sendLogins.done", action: close)
            case nil:
                SendLogins.Primary(title: "Send to Apple TV", identifier: "sendLogins.send", enabled: model.canSend) {
                    use(link)
                    model.send()
                }
            case .offline, .failed:
                SendLogins.Primary(title: "Try again", identifier: "sendLogins.retry") { model.send() }
            case .notSignedIn:
                SendLogins.Primary(title: "Send to Apple TV", identifier: "sendLogins.send", enabled: false) {}
            case .sending, .waiting:
                EmptyView()
            }
        }
    }

    /// Enter for a source whose login is not on this device: the login
    /// fields of the source's details, checked with the server on Check
    /// (apple-tv-login-from-iphone/the-iphone-takes-a-login-it-does-not-have).
    struct SendLoginsEnter: View {
        let row: SendLoginsModel.Row
        let model: SendLoginsModel
        let close: () -> Void
        @Environment(\.modelContext) private var context
        @State private var fields = SourceFields()
        @State private var error: String?
        @State private var checking = false

        var body: some View {
            NavigationStack {
                Form {
                    Section {
                        if row.source.kind == .stalker {
                            TextField("MAC address", text: $fields.mac)
                                .autocorrectionDisabled()
                                .accessibilityIdentifier("sendLogins.enter.mac")
                            TextField("Login", text: $fields.username, prompt: Text("Optional"))
                                .autocorrectionDisabled()
                                .accessibilityIdentifier("sendLogins.enter.username")
                        } else {
                            TextField("Username", text: $fields.username)
                                .autocorrectionDisabled()
                                #if os(iOS)
                                    .textInputAutocapitalization(.never)
                                #endif
                                .accessibilityIdentifier("sendLogins.enter.username")
                        }
                        SecureField("Password", text: $fields.password)
                            .accessibilityIdentifier("sendLogins.enter.password")
                    } header: {
                        Text("\(SendLogins.kindName(row.source.kind)) · \(row.source.url.host() ?? row.source.url.absoluteString)")
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            if let error {
                                Text(error)
                                    .font(.system(size: 15))
                                    .foregroundStyle(OnboardingForm.errorColor)
                                    .accessibilityIdentifier("sendLogins.enter.error")
                            }
                            Text("Checked with the server first, then kept in your iCloud Keychain on this \(SetupDevice.name).")
                        }
                    }
                }
                .navigationTitle(row.source.name)
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: close).accessibilityIdentifier("sendLogins.enter.cancel")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(checking ? "Checking…" : "Check", action: check)
                            .disabled(checking)
                            .accessibilityIdentifier("sendLogins.enter.check")
                    }
                }
            }
            .preferredColorScheme(.dark)
            .interactiveDismissDisabled(checking)
            .onAppear {
                if fields.url.isEmpty {
                    fields = SourceFields(kind: row.source.kind, name: row.source.name, url: row.source.url.absoluteString)
                }
            }
        }

        private func check() {
            checking = true
            Task {
                error = await model.enter(fields, for: row, in: context)
                checking = false
                if error == nil { close() }
            }
        }
    }
#endif
