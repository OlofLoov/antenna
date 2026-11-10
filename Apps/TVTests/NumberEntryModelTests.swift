import AntennaCore
import Foundation
import Testing

@testable import AntennaTV

/// Typing a channel number, on a clock advanced by hand.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct NumberEntryModelTests {
    let clock = ManualClock()
    let model: NumberEntryModel
    let channels: [Int: Channel] = [
        1: .fixture("one"), 104: .fixture("sport-one"), 105: .fixture("sport-two"), 1040: .fixture("long"),
    ]
    var tuned: [Channel] { tunes.values }
    let tunes = Tunes()

    @MainActor final class Tunes {
        var values: [Channel] = []
    }

    init() {
        let clock = clock
        model = NumberEntryModel(sleep: { try await clock.sleep($0) })
        let channels = channels
        model.lookup = { digits in
            let typed = digits.drop { $0 == "0" }
            guard !typed.isEmpty else { return nil }
            let match = channels.keys.sorted().first { String($0).hasPrefix(typed) }
            return match.flatMap { number in channels[number].map { ($0, number) } }
        }
        let tunes = tunes
        model.tune = { tunes.values.append($0) }
    }

    private func settle() async {
        for _ in 0..<200 { await Task.yield() }
    }

    private func type(_ text: String) {
        text.forEach(model.type)
    }

    @Test("tv-zap-bar-and-number-entry/typing-a-number-shows-the-match the box shows the digits and the matching name")
    func showsTheMatch() {
        type("10")
        #expect(model.phase == .typing)
        #expect(model.digits == "10")
        #expect(model.matchName == Channel.fixture("sport-one").name)
        model.type("x")
        #expect(model.digits == "10", "only digits count")
        type("9")
        #expect(model.matchName == nil, "blank when nothing matches")
        type("99")
        #expect(model.digits == "1099", "digits past the cap are ignored")
    }

    @Test("tv-zap-bar-and-number-entry/the-typed-channel-tunes two seconds after the last digit, or at once on Return")
    func tunes() async {
        type("104")
        await settle()
        clock.advance(by: .seconds(1))
        await settle()
        #expect(tuned.isEmpty)
        clock.advance(by: .seconds(1))
        await settle()
        #expect(tuned == [.fixture("sport-one")])
        #expect(model.phase == .closed)

        type("0105")
        model.commit()
        #expect(tuned.last == .fixture("sport-two"), "leading zeros find the channel")
        #expect(model.phase == .closed)
    }

    @Test("tv-zap-bar-and-number-entry/no-channel-with-that-number no match reads No channel n for a second")
    func noChannel() async {
        type("999")
        model.commit()
        #expect(model.phase == .noChannel("999"))
        #expect(tuned.isEmpty, "the same channel keeps playing")
        await settle()
        clock.advance(by: .seconds(1))
        await settle()
        #expect(model.phase == .closed)

        type("10")
        model.commit()
        #expect(model.phase == .noChannel("10"), "a prefix of a number is not that number")
        type("00")
        model.commit()
        #expect(model.phase == .noChannel("00"), "zeros alone match nothing")
    }

    @Test("tv-zap-bar-and-number-entry/correct-or-cancel-a-number Backspace gives two more seconds and Escape closes")
    func correctAndCancel() async {
        type("105")
        await settle()
        clock.advance(by: .milliseconds(1500))
        model.backspace()
        #expect(model.digits == "10")
        await settle()
        clock.advance(by: .milliseconds(1500))
        await settle()
        #expect(model.phase == .typing, "Backspace gave two more seconds")
        model.backspace()
        model.backspace()
        #expect(model.phase == .closed, "an emptied box goes away")

        type("104")
        model.cancel()
        #expect(model.phase == .closed)
        await settle()
        clock.advance(by: .seconds(3))
        await settle()
        #expect(tuned.isEmpty, "Menu or Escape never tunes")
    }

    @Test("tv-zap-bar-and-number-entry/play-pause-shows-the-bar half-typed digits are dropped")
    func dropped() {
        type("10")
        model.cancel()
        #expect(!model.isOpen)
        #expect(model.digits.isEmpty)
    }
}
