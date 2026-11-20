import Foundation

/// Folding and word tests for the Live filter and Search, kept fast for
/// tens of thousands of names per keystroke.
enum FoldedText {
    /// `text` without case or accents. ASCII text only needs A to Z
    /// lowered, which gives the same result as Foundation's folding
    /// without the call.
    static func fold(_ text: String) -> String {
        var ascii = true
        for byte in text.utf8 where byte >= 0x80 {
            ascii = false
            break
        }
        guard ascii else { return text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }
        var lowered = false
        for byte in text.utf8 where byte >= 0x41 && byte <= 0x5A {
            lowered = true
            break
        }
        guard lowered else { return text }
        return String(decoding: text.utf8.map { $0 >= 0x41 && $0 <= 0x5A ? $0 | 0x20 : $0 }, as: UTF8.self)
    }

    /// The bytes a byte search compares: UTF-8 in canonical composed form,
    /// so text the string comparison calls equal has the same bytes.
    static func bytes(_ folded: String) -> [UInt8] {
        let utf8 = folded.utf8
        if utf8.allSatisfy({ $0 < 0x80 }) { return Array(utf8) }
        return Array(folded.precomposedStringWithCanonicalMapping.utf8)
    }
}

/// One folded word to look for, with the bytes a byte search compares.
struct FoldedNeedle: Sendable, Equatable {
    let text: String
    let bytes: [UInt8]

    init(_ folded: String) {
        text = folded
        bytes = FoldedText.bytes(folded)
    }
}

/// Many folded texts in one byte buffer. A word test is one `memmem` per
/// text. Text with only ASCII answers from the bytes alone; other text
/// that the bytes match is checked again with the string comparison the
/// filter has always used, so results never change, only the time.
struct FoldedTexts: Sendable {
    let texts: [String]
    private let bytes: [UInt8]
    /// Where each text's bytes start in `bytes`, and one past the last.
    private let starts: [Int]
    /// True when one byte is one character, so a byte match is the answer.
    private let ascii: [Bool]

    init(_ folded: [String]) {
        var bytes: [UInt8] = []
        var starts: [Int] = [0]
        var ascii: [Bool] = []
        starts.reserveCapacity(folded.count + 1)
        ascii.reserveCapacity(folded.count)
        for text in folded {
            let encoded = FoldedText.bytes(text)
            bytes.append(contentsOf: encoded)
            starts.append(bytes.count)
            // A carriage return before a line feed is one character, so text holding one is checked as a string.
            ascii.append(text.utf8.allSatisfy { $0 < 0x80 && $0 != 0x0D })
        }
        texts = folded
        self.bytes = bytes
        self.starts = starts
        self.ascii = ascii
    }

    var count: Int { texts.count }

    /// True when text `index` is not empty.
    func hasText(_ index: Int) -> Bool {
        starts[index + 1] > starts[index]
    }

    /// True when every needle is part of text `index`, as `String.contains`
    /// would say for the folded text. True for no needles.
    func contains(_ index: Int, all needles: [FoldedNeedle]) -> Bool {
        matches([index], all: needles)[0]
    }

    /// For every text, whether it is not empty and every needle is part of it.
    func nonEmptyMatches(all needles: [FoldedNeedle]) -> [Bool] {
        var found = matches(Array(0..<count), all: needles)
        for index in found.indices where found[index] && !hasText(index) { found[index] = false }
        return found
    }

    /// For each of `indices`, whether every needle is part of that text, as
    /// `contains(_:all:)` says. A negative index is no text and never matches.
    /// One pass over raw bytes, so a debug build stays quick too.
    func matches(_ indices: [Int], all needles: [FoldedNeedle]) -> [Bool] {
        var words: [UInt8] = []
        var wordEnds: [Int] = []
        for needle in needles where !needle.bytes.isEmpty {
            words += needle.bytes
            wordEnds.append(words.count)
        }
        var found = [Bool](repeating: false, count: indices.count)
        bytes.withUnsafeBytes { textBuffer in
            words.withUnsafeBytes { wordBuffer in
                starts.withUnsafeBufferPointer { starts in
                    guard let textBase = textBuffer.baseAddress ?? UnsafeRawPointer(bitPattern: 1),
                        let wordBase = wordBuffer.baseAddress ?? UnsafeRawPointer(bitPattern: 1)
                    else { return }
                    for (slot, index) in indices.enumerated() where index >= 0 {
                        let start = starts[index]
                        let length = starts[index + 1] - start
                        var all = true
                        var wordStart = 0
                        for wordEnd in wordEnds {
                            if memmem(textBase + start, length, wordBase + wordStart, wordEnd - wordStart) == nil {
                                all = false
                                break
                            }
                            wordStart = wordEnd
                        }
                        found[slot] = all
                    }
                }
            }
        }
        // A byte match in text beyond ASCII may cross a character, so the string comparison has the last word.
        for (slot, index) in indices.enumerated() where found[slot] && !ascii[index] {
            let text = texts[index]
            found[slot] = needles.allSatisfy { text.contains($0.text) }
        }
        return found
    }
}
