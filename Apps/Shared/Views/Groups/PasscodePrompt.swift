import AntennaCore
import SwiftData
import SwiftUI

#if canImport(LocalAuthentication) && !os(tvOS)
    import LocalAuthentication
#endif

/// Which passcode flow the prompt runs.
enum PasscodeFlow: Equatable {
    /// Open the locks with the passcode (group-management/unlock-with-the-passcode).
    case unlock
    /// Four digits twice, the first time a group is locked
    /// (group-management/lock-a-group-with-a-passcode).
    case create
    /// The current passcode, then a new one twice.
    case change
    /// A new one twice, after the device's own check
    /// (group-management/reset-a-forgotten-passcode).
    case reset
}

/// The passcode prompt as a screen: it owns the digits typed so far, checks
/// them against the synced check value through `GroupLocks`, and stores a
/// new passcode. `finished` gets true once the flow succeeded, false when
/// the user cancels.
struct PasscodePrompt: View {
    let flow: PasscodeFlow
    /// What is locked, as "Movies is locked."
    let message: String
    let finished: (Bool) -> Void

    @Environment(\.modelContext) private var context
    @Environment(GroupLocks.self) private var locks: GroupLocks?
    @Query private var records: [PasscodeRecord]
    @State private var step: Step?
    @State private var typed = ""
    @State private var error: String?
    @State private var firstEntry: String?
    @State private var waitEnds = 0

    private enum Step: Equatable { case current, new, confirm }

    var body: some View {
        content
            .overlay(alignment: .topLeading) {
                Button("Cancel") { finished(false) }
                    .padding(24)
                    .accessibilityIdentifier("groups.passcode.cancel")
            }
            .task(id: waitEnds) {
                let wait = locks?.waitRemaining ?? 0
                guard wait > 0 else { return }
                try? await Task.sleep(for: .seconds(wait))
                if !Task.isCancelled { waitEnds += 1 }
            }
    }

    @ViewBuilder private var content: some View {
        if currentStep == .current, PasscodeStore.current(records) == nil {
            PasscodePad.Waiting(message: message)
        } else {
            PasscodePad.Prompt(
                title: title, message: changedElsewhere ? "The passcode was changed on another device." : message,
                filled: typed.count, error: shownError, enabled: waitRemaining == 0, type: type, delete: delete
            ) {
                if flow == .unlock { PasscodeForgot { finished(true) } }
            }
        }
    }

    private var currentStep: Step {
        step ?? (flow == .unlock || flow == .change ? .current : .new)
    }

    private var title: String {
        switch currentStep {
        case .current: "Enter passcode"
        case .new: flow == .create ? "Set a passcode" : "Enter a new passcode"
        case .confirm: "Enter it again"
        }
    }

    private var changedElsewhere: Bool { currentStep == .current && (locks?.changedElsewhere(records) ?? false) }

    private var waitRemaining: TimeInterval {
        _ = waitEnds
        return currentStep == .current ? locks?.waitRemaining ?? 0 : 0
    }

    private var shownError: String? {
        let wait = waitRemaining
        guard wait == 0 else { return "Try again in \(Int(wait.rounded(.up))) seconds" }
        return error
    }

    private func delete() {
        if !typed.isEmpty { typed.removeLast() }
    }

    private func type(_ digit: Character) {
        guard typed.count < 4 else { return }
        typed.append(digit)
        guard typed.count == 4 else { return }
        let entry = typed
        typed = ""
        submit(entry)
    }

    private func submit(_ entry: String) {
        switch currentStep {
        case .current:
            switch locks?.enter(entry, records: records) ?? .noPasscode {
            case .right:
                error = nil
                if flow == .unlock { return finished(true) }
                step = .new
            case .wrong: error = "Wrong passcode"
            case .waiting: waitEnds += 1
            case .noPasscode: break
            }
        case .new:
            firstEntry = entry
            error = nil
            step = .confirm
        case .confirm:
            guard entry == firstEntry else {
                firstEntry = nil
                error = "The passcodes did not match. Start again."
                step = .new
                return
            }
            guard let record = PasscodeStore.set(entry, in: context) else { return }
            locks?.remember(record)
            locks?.open()
            finished(true)
        }
    }
}

/// Forgot passcode under the prompt. On iPhone, iPad and Mac it checks the
/// device's own passcode, login password, Face ID or Touch ID, then runs
/// the reset flow; on Apple TV it says where to reset it
/// (group-management/reset-a-forgotten-passcode).
struct PasscodeForgot: View {
    /// Called once a new passcode is set and the locks are open.
    let reset: () -> Void
    @State private var resetting = false

    var body: some View {
        #if os(tvOS)
            Text("Forgot it? Reset the passcode in Antenna on your iPhone, iPad or Mac.")
                .foregroundStyle(Palette.textMuted)
                .accessibilityIdentifier("groups.passcode.forgot")
        #else
            Button("Forgot passcode?") {
                Task {
                    if await Self.deviceOwnerConfirms() { resetting = true }
                }
            }
            .accessibilityIdentifier("groups.passcode.forgot")
            .sheet(isPresented: $resetting) {
                PasscodePrompt(flow: .reset, message: "Set a new passcode. Every locked group stays locked.") { done in
                    resetting = false
                    if done { reset() }
                }
            }
        #endif
    }

    #if !os(tvOS)
        /// Asks the system to confirm the device's owner. UI tests skip the
        /// system sheet with `-ui-testing-groups-owner`.
        @MainActor static func deviceOwnerConfirms() async -> Bool {
            #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-ui-testing-groups-owner") { return true }
            #endif
            let context = LAContext()
            return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Reset the group passcode")) ?? false
        }
    #endif
}
