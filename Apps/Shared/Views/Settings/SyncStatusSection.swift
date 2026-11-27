#if DEBUG
    import AntennaCore
    import SwiftUI

    /// Debug builds only: the Sync status section in Settings, for finding
    /// out on a device why sources or Play on do not reach the other
    /// devices. It shows what `SyncStatus` recorded and the Play on device
    /// records as CloudKit returns them, read again on "Read devices again".
    /// Under UI tests it reads no devices.
    struct SyncStatusSection: View {
        @Environment(\.locale) private var locale
        #if !os(tvOS)
            @Environment(\.playDestination) private var destination
        #endif
        @State private var devices: Result<[PlayDeviceInfo], PlayOnStoreError>?
        @State private var reading = false
        private var status: SyncStatus { .shared }

        var body: some View {
            Section {
                row("Container", status.container ?? "none")
                row("iCloud Drive identity", status.identityPresent ? "present" : "missing")
                row("CloudKit account", status.account)
                row("Play on and login sweep", status.playOnEnabled ? "on" : "off")
                event("Setup", status.setup)
                event("Import", status.importing)
                event("Export", status.exporting)
                deviceRows
                Button {
                    Task { await read() }
                } label: {
                    Text(verbatim: reading ? "Reading devices…" : "Read devices again")
                }
                .disabled(reading)
                .accessibilityIdentifier("settings.debug.readDevices")
            } header: {
                Text(verbatim: "Sync status")
            } footer: {
                Text(verbatim: "The last iCloud sync events on this device and the Play on device records. Debug builds only.")
            }
            .task {
                await status.checkAccount()
                await read()
            }
        }

        @ViewBuilder private var deviceRows: some View {
            switch devices {
            case nil:
                row("Play on devices", "not read")
            case .failure(let error):
                row("Play on devices", "error: \(error)")
            case .success(let list) where list.isEmpty:
                row("Play on devices", "none")
            case .success(let list):
                ForEach(list.sorted { $0.lastSeen > $1.lastSeen }, id: \.id) { device in
                    row(device.name.isEmpty ? "(no name)" : device.name, "\(device.kind.rawValue), seen \(time(device.lastSeen))")
                }
            }
        }

        private func event(_ label: String, _ event: SyncStatus.Event?) -> some View {
            row(label, event.map(describe) ?? "none yet")
        }

        private func describe(_ event: SyncStatus.Event) -> String {
            guard let ended = event.ended else { return "running since \(time(event.started))" }
            if let failure = event.failure { return "failed \(time(ended)): \(failure.line)" }
            return "\(event.succeeded ? "succeeded" : "did not succeed") \(time(ended))"
        }

        private func row(_ label: String, _ value: String) -> some View {
            LabeledContent {
                Text(verbatim: value)
                    #if !os(tvOS)
                        .textSelection(.enabled)
                    #endif
            } label: {
                Text(verbatim: label)
            }
            #if os(tvOS)
                // Focusable, so the remote can move down the rows and the list scrolls to them.
                .focusable()
            #endif
        }

        private func time(_ date: Date) -> String {
            date.formatted(Date.FormatStyle(date: .abbreviated, time: .standard, locale: locale))
        }

        private func read() async {
            if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-ui-testing") }) { return }
            reading = true
            defer { reading = false }
            do {
                devices = .success(try await CloudKitPlayDevices().all())
            } catch {
                devices = .failure(error)
            }
            #if !os(tvOS)
                await destination?.refresh()
            #endif
        }
    }
#endif
