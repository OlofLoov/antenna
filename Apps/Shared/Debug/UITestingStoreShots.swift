#if DEBUG
    import AntennaCore
    import Foundation

    /// What the App Store screenshot walk changes on a scripted launch
    /// (add-store-localization, polish-store-screenshots), compiled into
    /// Debug builds only.
    ///
    /// `-ui-testing-store-shots` hides the test probes and the Apple TV
    /// remote hints, gives every channel a full guide, pins the wall clock
    /// at 9:41, gives the scripted movies and series posters and backdrops,
    /// and plays `StorePicture.mp4` on every player surface in place of the
    /// scripted engines' black picture. The clip and the art are made up:
    /// `scripts/make-store-picture.sh` draws a landscape at sunrise with
    /// ffmpeg and `scripts/make-store-art.py` draws abstract shapes. They
    /// sit in the Debug app bundle only and nothing reaches the network.
    enum UITestingStoreShots {
        static let argument = "-ui-testing-store-shots"

        static var isOn: Bool { ProcessInfo.processInfo.arguments.contains(argument) }

        /// The minute of the day the store set shows, 9:41 as on the
        /// simulator's status bar.
        static let shownMinute = 9 * 60 + 41

        /// Makes the app's wall clock read 9:41 at launch, so the guide, the
        /// now line and the info bar agree with the status bar. The app runs
        /// in a fixed time zone whose offset from GMT puts this moment at
        /// 9:41, set as the process's system time zone so every formatter
        /// and calendar follows it. The date itself stays real, so nothing
        /// that measures time changes. Does nothing without the argument.
        static func pinClock(now: Date = .now) {
            guard isOn, let zone = zone(showing: shownMinute, at: now) else { return }
            setenv("TZ", zone.identifier, 1)
            NSTimeZone.resetSystemTimeZone()
        }

        /// The time zone in which `now` falls on `minute` of the day, with
        /// an offset of at most 12 hours either way.
        static func zone(showing minute: Int, at now: Date) -> TimeZone? {
            let utcMinute = Int(now.timeIntervalSince1970 / 60) % 1440
            var offset = (minute - utcMinute) % 1440
            if offset > 720 { offset -= 1440 }
            if offset <= -720 { offset += 1440 }
            return TimeZone(secondsFromGMT: offset * 60)
        }

        enum Art: String {
            case poster, backdrop
        }

        /// The made-up poster or backdrop `scripts/make-store-art.py` drew
        /// for a scripted shelf title (`xtream#cabin#vod#1`), as a file in
        /// the app bundle; nil without the argument or the file.
        static func art(for titleID: String, _ art: Art) -> URL? {
            let parts = titleID.split(separator: "#")
            guard isOn, parts.count == 4 else { return nil }
            return Bundle.main.url(forResource: "StoreArt-\(parts[1])-\(parts[2])-\(parts[3])-\(art.rawValue)", withExtension: "jpg")
        }

        /// The clip looping on one muted player shared by every surface; nil
        /// without the argument or without the clip in the bundle.
        @MainActor static let picture: AVPlayerEngine.StorePicture? = {
            guard isOn, let url = Bundle.main.url(forResource: "StorePicture", withExtension: "mp4") else { return nil }
            return AVPlayerEngine.StorePicture(url: url)
        }()

        /// A guide where every channel has a programme on now and more after
        /// it, from two hours before launch to six hours after; nil without
        /// the argument. Programmes start on the quarter hour, as a provider's do.
        @MainActor
        static func guide(launched: Date) -> OverlayGuide? {
            guard isOn else { return nil }
            // The half hour on the wall clock, which pinClock may have set
            // to an offset that is not a whole hour.
            let wholeMinute = Date(timeIntervalSince1970: (launched.timeIntervalSince1970 / 60).rounded(.down) * 60)
            let minute = Calendar.current.component(.minute, from: wholeMinute)
            let halfHour = wholeMinute.addingTimeInterval(-Double(minute % 30) * 60)
            let start = halfHour.addingTimeInterval(-2 * 3600)
            let end = launched.addingTimeInterval(6 * 3600)
            let cache = Cache()
            func programmes(_ channel: Channel) -> [Programme] {
                let key = channel.epgID ?? channel.id
                if let cached = cache.programmes[key] { return cached }
                let made = schedule(for: key, from: start, until: end)
                cache.programmes[key] = made
                return made
            }
            return OverlayGuide(
                state: { _ in .loaded },
                current: { channel, date in programmes(channel).first { $0.start <= date && date < $0.stop } },
                next: { channel, date, count in Array(programmes(channel).filter { $0.start >= date }.prefix(count)) },
                programmes: { channel, interval in
                    programmes(channel).filter { $0.stop > interval.start && $0.start < interval.end }
                },
                horizon: { DateInterval(start: start, end: end) })
        }

        @MainActor
        private final class Cache {
            var programmes: [String: [Programme]] = [:]
        }

        /// The channel's titles and minutes repeated from `start`, shifted by
        /// its offset so the channels do not all change at once.
        private static func schedule(for key: String, from start: Date, until end: Date) -> [Programme] {
            let entry = schedules[key] ?? Entry(offset: 0, slots: [("Live Desk", 60), ("Studio Hour", 60)])
            var programmes: [Programme] = []
            var time = start.addingTimeInterval(Double(entry.offset - 60) * 60)
            var index = 0
            while time < end {
                let (title, minutes) = entry.slots[index % entry.slots.count]
                let stop = time.addingTimeInterval(Double(minutes) * 60)
                programmes.append(Programme(channelID: key, start: time, stop: stop, title: title))
                time = stop
                index += 1
            }
            return programmes
        }

        private struct Entry {
            let offset: Int
            let slots: [(String, Int)]
        }

        /// Made-up titles for the channels of the scripted Live launch and
        /// the screenshot seed, by guide id.
        private static let schedules: [String: Entry] = [
            "news-one": Entry(offset: 0, slots: [("News Hour", 60), ("Weather", 30), ("Business Today", 30), ("World Desk", 60)]),
            "news-two": Entry(offset: 30, slots: [("Headlines", 30), ("The Interview", 60), ("Market Watch", 30)]),
            "world-report": Entry(offset: 15, slots: [("World Report", 60), ("Global Desk", 45), ("Correspondents", 30)]),
            "city-24": Entry(offset: 45, slots: [("City Tonight", 30), ("Traffic", 30), ("Town Hall", 60)]),
            "business-now": Entry(offset: 0, slots: [("Opening Bell", 60), ("Market Close", 30), ("Money Talk", 30)]),
            "sport-one": Entry(offset: 15, slots: [("Match Day", 90), ("Highlights", 30), ("Sport Desk", 60)]),
            "sport-two": Entry(offset: 30, slots: [("Cycling", 120), ("Sport News", 30)]),
            "football-live": Entry(offset: 45, slots: [("Cup Final", 120), ("Post-Match", 30)]),
            "tennis-live": Entry(offset: 0, slots: [("Quarter-Final", 120), ("Court Report", 30)]),
            "movies-one": Entry(offset: 30, slots: [("The Long Harbor", 120), ("Night Ferry", 90)]),
            "classic-cinema": Entry(offset: 15, slots: [("Paper Cities", 90), ("Snow Day", 90)]),
            "family-films": Entry(offset: 45, slots: [("Quiet Engines", 90), ("Salt Road", 90)]),
            "action-max": Entry(offset: 0, slots: [("Second Act", 120), ("Harbor Watch", 60)]),
            "kids-one": Entry(offset: 30, slots: [("Cartoon Club", 30), ("Science Lab", 30), ("Story Time", 30)]),
            "cabin-film": Entry(offset: 15, slots: [("Northern Lights", 90), ("Cabin Classics", 90)]),
        ]
    }
#endif
