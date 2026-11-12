import AntennaCore
import SwiftUI

#if os(iOS)
    import UIKit
#endif

/// Settings › Reminders on every platform (programme-reminders capability;
/// `iPhone-Reminders`): how long before start this device reminds, a notice
/// when it cannot notify, and every upcoming reminder soonest first with its
/// moved or dropped note. Removing asks first on Apple TV and Mac.
struct RemindersScreen: View {
    @Environment(\.reminders) private var reminders
    @Environment(\.openURL) private var openURL
    @State private var removing: Reminder?
    @State private var now = Date.now

    var body: some View {
        List {
            if let reminders {
                leadTime(reminders)
                notice(reminders)
                upcoming(reminders)
            }
        }
        .navigationTitle("Reminders")
        .alert(
            "Remove reminder?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), presenting: removing
        ) { shown in
            Button("Remove", role: .destructive) { reminders?.remove(shown) }
                .accessibilityIdentifier("reminders.confirmRemove")
            Button("Cancel", role: .cancel) {}
        } message: { shown in
            Text("\(shown.title) will not remind you on any of your devices.")
        }
        .task { await reminders?.refreshAuthorization() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                now = .now
            }
        }
    }

    /// Before start: at start, 5, 10, 15 or 30 minutes, kept on this device
    /// (programme-reminders/choose-how-early-reminders-go-off).
    private func leadTime(_ reminders: ReminderCenter) -> some View {
        Section("Remind me") {
            Picker("Before start", selection: Binding(get: { reminders.leadTime }, set: { reminders.setLeadTime($0) })) {
                ForEach(ReminderLeadTime.allCases, id: \.self) { lead in
                    Text(lead.title).tag(lead)
                }
            }
            .accessibilityIdentifier("reminders.leadTime")
        }
    }

    /// Why this device shows reminders only while Antenna is open, with a way
    /// to allow notifications where there is one
    /// (programme-reminders/the-app-says-when-reminders-cannot-notify).
    @ViewBuilder
    private func notice(_ reminders: ReminderCenter) -> some View {
        switch reminders.authorization {
        case .denied:
            RemindersNotice(text: ReminderText.cannotNotify) {
                if let url = Self.notificationSettings {
                    Button("Open Settings") { openURL(url) }.accessibilityIdentifier("reminders.openSettings")
                }
            }
        case .notDetermined:
            RemindersNotice(text: ReminderText.notAskedYet) {
                Button("Allow notifications") { Task { await reminders.requestAuthorization() } }
                    .accessibilityIdentifier("reminders.allowNotifications")
            }
        case .unavailable:
            RemindersNotice(text: ReminderText.television) {}
        case .allowed, nil:
            EmptyView()
        }
    }

    private func upcoming(_ reminders: ReminderCenter) -> some View {
        Section {
            if reminders.upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ReminderText.empty).font(.headline)
                    Text(ReminderText.emptyHint).foregroundStyle(Palette.textMuted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("reminders.empty")
            }
            // Each row's day follows the clock and the current time zone.
            ForEach(Array(reminders.upcoming.enumerated()), id: \.element.key) { index, reminder in
                row(reminder, index: index, now: now)
            }
        } header: {
            HStack {
                Text("Upcoming")
                Spacer()
                if let count = ReminderText.count(reminders.upcoming.count) {
                    Text(count).accessibilityIdentifier("reminders.count")
                }
            }
        } footer: {
            Text(ReminderText.syncNote)
        }
    }

    @ViewBuilder
    private func row(_ reminder: Reminder, index: Int, now: Date) -> some View {
        let text = ReminderText()
        let label = ReminderRow(
            title: reminder.title, detail: text.rowDetail(reminder, now: now), status: text.rowStatus(reminder), dimmed: reminder.notListed,
            identifier: "reminders.row.\(index)")
        #if os(tvOS)
            Button {
                removing = reminder
            } label: {
                label
            }
            .accessibilityIdentifier("reminders.row.\(index)")
        #elseif os(macOS)
            label
                .accessibilityIdentifier("reminders.row.\(index)")
                .contextMenu { Button("Remove") { removing = reminder } }
                .swipeActions { Button("Remove", role: .destructive) { removing = reminder } }
        #else
            label
                .accessibilityIdentifier("reminders.row.\(index)")
                .swipeActions {
                    Button("Remove", role: .destructive) { reminders?.remove(reminder) }
                        .accessibilityIdentifier("reminders.remove.\(index)")
                }
        #endif
    }

    private static var notificationSettings: URL? {
        #if os(iOS)
            URL(string: UIApplication.openNotificationSettingsURLString)
        #elseif os(macOS)
            URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
        #else
            nil
        #endif
    }
}

/// The Settings list's Reminders row, with the upcoming count when there are any.
struct RemindersSettingsRow: View {
    @Environment(\.reminders) private var reminders

    var body: some View {
        NavigationLink {
            RemindersScreen()
        } label: {
            LabeledContent("Reminders", value: ReminderText.count(reminders?.upcoming.count ?? 0) ?? "")
        }
        .accessibilityIdentifier("settings.reminders")
    }
}

/// The muted bell with a line of text, and the action under it.
private struct RemindersNotice<Action: View>: View {
    let text: String
    @ViewBuilder var action: Action

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.slash")
                .foregroundStyle(Palette.textMuted)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                action
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reminders.permissionDenied")
    }
}
