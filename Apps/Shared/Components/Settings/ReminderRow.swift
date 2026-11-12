import SwiftUI

/// One reminder in Settings › Reminders (`iPhone-Reminders`): a bell, the
/// title, "Today 22:00 – 23:15 · Sport One", and a note when the guide
/// moved or dropped the programme. A dropped one has an outlined, muted bell.
struct ReminderRow: View {
    let title: String
    let detail: String
    let status: String?
    let dimmed: Bool
    let identifier: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: dimmed ? "bell" : "bell.fill")
                .foregroundStyle(dimmed ? Palette.textMuted : Palette.text)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textMuted)
                    .lineLimit(1)
                if let status {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(Palette.textMuted)
                        .lineLimit(1)
                        .accessibilityIdentifier("\(identifier).status")
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Reminder rows") {
    List {
        ReminderRow(
            title: "Match of the Day", detail: "Today 22:00 – 23:15 · Sport One", status: nil, dimmed: false, identifier: "reminders.row.0")
        ReminderRow(
            title: "La Liga: Sevilla v Betis", detail: "Tomorrow 21:00 – 23:00 · Sport Two", status: "Moved from 20:00", dimmed: false,
            identifier: "reminders.row.1")
        ReminderRow(
            title: "Handball: EHF Champions League", detail: "Thu 19:45 – 21:30 · Arena HD", status: "No longer in the guide", dimmed: true,
            identifier: "reminders.row.2")
    }
    .preferredColorScheme(.dark)
}
