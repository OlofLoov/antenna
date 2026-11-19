import Foundation

/// A launch environment whose time zone puts the app's clock between 12:00
/// and 12:59 today. Guide fixtures start their programmes around launch, so
/// a test that expects them on today passes at any hour, including the half
/// hour before midnight. Shared by the iPhone, iPad and Apple TV UI tests.
enum Midday {
    static var environment: [String: String] {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        let ahead = 12 - utc.component(.hour, from: .now)
        // Etc/GMT names count the other way: Etc/GMT-3 is three hours ahead of UTC.
        return ["TZ": ahead == 0 ? "UTC" : "Etc/GMT\(ahead > 0 ? "-" : "+")\(abs(ahead))"]
    }
}
