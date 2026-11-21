import Observation

/// Values by key, where a view that reads one key redraws only when that
/// key's value changes. A dictionary in an `@Observable` model redraws
/// every reader on any change, which on Apple TV meant every poster on
/// screen for each info answer and each progress read
/// (movies-and-series-browsing/browsing-stays-responsive).
@MainActor
final class KeyedValues<Key: Hashable, Value: Equatable> {
    private var cells: [Key: KeyedCell<Value>] = [:]

    init() {}

    /// The value for `key`, nil when none is set. A reader in a view's
    /// body redraws when this key's value changes, set or cleared.
    func value(_ key: Key) -> Value? {
        cell(key).value
    }

    /// Sets one key's value; readers of other keys do not redraw.
    func set(_ value: Value?, for key: Key) {
        guard let cell = cells[key] else {
            if value != nil { cells[key] = KeyedCell(value) }
            return
        }
        if cell.value != value { cell.value = value }
    }

    /// Makes the values `all`: keys that are missing read nil, and only
    /// keys whose value changed redraw their readers.
    func replace(with all: [Key: Value]) {
        for (key, cell) in cells where cell.value != all[key] {
            cell.value = all[key]
        }
        for (key, value) in all where cells[key] == nil {
            cells[key] = KeyedCell(value)
        }
    }

    /// A key read before its value arrives gets a cell, so the reader
    /// hears when it is set.
    private func cell(_ key: Key) -> KeyedCell<Value> {
        if let cell = cells[key] { return cell }
        let cell = KeyedCell<Value>(nil)
        cells[key] = cell
        return cell
    }
}

/// One key's value in `KeyedValues`.
@MainActor @Observable
final class KeyedCell<Value> {
    var value: Value?

    init(_ value: Value?) {
        self.value = value
    }
}
