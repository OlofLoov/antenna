#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    extension View {
        /// Takes digits, Return, Backspace and Escape from a hardware keyboard
        /// while `enabled` (full-screen Live with nothing over the picture),
        /// shows the number box at the top left, and tunes through `tune`
        /// (tv-zap-bar-and-number-entry/typing-a-number-shows-the-match).
        /// `typing` runs on each digit, so the info bar can hide.
        func numberEntry(
            _ model: NumberEntryModel, enabled: Bool, catalogue: Catalogue<PersistentIdentifier>,
            typing: @escaping @MainActor () -> Void, tune: @escaping @MainActor (Channel) -> Void
        ) -> some View {
            modifier(NumberEntryInput(model: model, enabled: enabled, catalogue: catalogue, typing: typing, tune: tune))
        }
    }

    private struct NumberEntryInput: ViewModifier {
        let model: NumberEntryModel
        let enabled: Bool
        let catalogue: Catalogue<PersistentIdentifier>
        let typing: @MainActor () -> Void
        let tune: @MainActor (Channel) -> Void

        func body(content: Content) -> some View {
            content
                .overlay(alignment: .topLeading) {
                    if let box {
                        ZapBar.NumberBox(content: box)
                            .padding(.leading, 64)
                            .padding(.top, 44)
                            .allowsHitTesting(false)
                    }
                }
                .onKeyPress(phases: .down) { press in handle(press) }
                .onChange(of: enabled) { _, now in
                    if !now { model.cancel() }
                }
                .task(id: catalogue.count(of: .all)) { configure() }
        }

        private var box: ZapBar.NumberBox.Content? {
            switch model.phase {
            case .closed: nil
            case .typing: .typing(digits: model.digits, name: model.matchName)
            case .noChannel(let digits): .noChannel(digits)
            }
        }

        private func handle(_ press: KeyPress) -> KeyPress.Result {
            guard enabled else { return .ignored }
            switch press.key {
            case .return:
                guard model.isOpen else { return .ignored }
                model.commit()
            case .delete:
                guard model.isOpen else { return .ignored }
                model.backspace()
            case .escape:
                guard model.isOpen else { return .ignored }
                model.cancel()
            default:
                guard let digit = press.characters.first, press.characters.count == 1, digit.isASCII, digit.isNumber else {
                    return .ignored
                }
                typing()
                model.type(digit)
            }
            return .handled
        }

        /// Looks numbers up in All channels and caps the digits at the longest number.
        private func configure() {
            let catalogue = self.catalogue
            let longest = catalogue.rows(in: .all).compactMap { catalogue.number(for: $0) }.max() ?? 0
            model.maxDigits = max(4, String(longest).count)
            model.lookup = { digits in
                guard let key = catalogue.match(digits: digits), let channel = catalogue.channel(for: key),
                    let number = catalogue.number(for: key)
                else { return nil }
                return (channel, number)
            }
            model.tune = tune
        }
    }
#endif
