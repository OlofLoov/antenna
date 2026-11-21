import Foundation
import Observation
import Testing

@testable import Antenna

/// A poster that reads one title's value redraws only for that title.
@MainActor
@Suite struct KeyedValuesTests {
    /// Set when an observed value changes.
    final class Changed: @unchecked Sendable {
        var value = false
    }

    private func redraws(_ values: KeyedValues<String, String>, reading key: String, after change: () -> Void) -> Bool {
        let changed = Changed()
        withObservationTracking {
            _ = values.value(key)
        } onChange: {
            changed.value = true
        }
        change()
        return changed.value
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive an answer for another title does not redraw this poster")
    func onlyItsOwnKey() {
        let values = KeyedValues<String, String>()
        #expect(!redraws(values, reading: "a") { values.set("Plot B", for: "b") })
        #expect(redraws(values, reading: "a") { values.set("Plot A", for: "a") }, "a value read before it arrived still reaches the reader")
        #expect(!redraws(values, reading: "a") { values.set("Plot A", for: "a") }, "the same value again redraws nothing")
        #expect(values.value("a") == "Plot A")
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive replacing every value redraws only the keys that changed")
    func replaceChangesOnlyWhatDiffers() {
        let values = KeyedValues<String, String>()
        values.replace(with: ["a": "1", "b": "2"])
        #expect(!redraws(values, reading: "a") { values.replace(with: ["a": "1", "b": "3"]) })
        #expect(redraws(values, reading: "b") { values.replace(with: ["a": "1"]) }, "a key that goes reads nil")
        #expect(values.value("b") == nil)
    }
}
