import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The iPhone side: which links open the sheet, and how the sending screen
/// follows the upload, with a scripted iCloud and upload.
@MainActor
@Suite struct SetupInboxTests {
    private func link() -> SetupLink { SetupLink(token: PairingToken()) }

    @Test("iphone-as-setup-device/scanning-opens-the-setup-form-on-the-iphone: a link opens the form once per code")
    func oncePerCode() {
        let inbox = SetupInbox()
        let link = link()
        #expect(inbox.receive(link.url))
        #expect(inbox.pending?.kind == .setup(link))
        let first = inbox.pending?.id
        // The same code, or another, while the sheet is open opens nothing new.
        inbox.receive(link.url)
        inbox.receive(handoff: self.link().userInfo)
        #expect(inbox.pending?.id == first)
        #expect(inbox.holdsApp)
        // Cancel before Connect forgets the code.
        inbox.take()
        #expect(!inbox.holdsApp)
        inbox.receive(handoff: link.userInfo)
        #expect(inbox.pending?.kind == .setup(link))
        // Continue uses it.
        inbox.use(link)
        inbox.take()
        inbox.receive(link.url)
        #expect(inbox.pending == nil)
    }

    @Test("iphone-as-setup-device/scanning-opens-the-setup-form-on-the-iphone: a damaged or newer link opens the plain form")
    func damagedOrNewer() throws {
        let inbox = SetupInbox()
        #expect(inbox.receive(try #require(URL(string: "https://antenna.codecrave.se/setup?v=1&t=broken"))))
        #expect(inbox.pending?.kind == .damaged)
        inbox.take()
        #expect(inbox.receive(try #require(URL(string: "https://antenna.codecrave.se/setup?v=2&t=whatever"))))
        #expect(inbox.pending?.kind == .newer)
        inbox.take()
        // Not a setup link at all: left to the other handlers, such as a shared file.
        #expect(!inbox.receive(URL(fileURLWithPath: "/tmp/list.m3u")))
        inbox.receive(handoff: ["token": "short"])
        #expect(inbox.pending == nil)
    }

    private func delivery(signedIn: Bool, exports: ScriptedExports, timeout: Gate) -> SetupDelivery {
        var dependencies = SetupDelivery.Dependencies(identity: FixedICloudIdentity(signedIn: signedIn), exports: exports)
        dependencies.sleep = { _ in await timeout.wait() }
        return SetupDelivery(savedAt: Date(timeIntervalSince1970: 1000), dependencies: dependencies)
    }

    /// A wait that ends when the test opens it.
    @MainActor final class Gate {
        private var waiters: [CheckedContinuation<Void, Never>] = []
        private var open = false

        func wait() async {
            guard !open else { return }
            await withCheckedContinuation { waiters.append($0) }
        }

        func release() {
            open = true
            waiters.forEach { $0.resume() }
            waiters = []
        }
    }

    private func settle() async {
        for _ in 0..<20 { await Task.yield() }
    }

    @Test("iphone-as-setup-device/the-iphone-says-what-to-check-when-sending-stalls: not sent after the wait, then confirmed")
    func stallsThenConfirms() async {
        let exports = ScriptedExports()
        let timeout = Gate()
        let delivery = delivery(signedIn: true, exports: exports, timeout: timeout)
        let run = Task { await delivery.run() }
        await settle()
        #expect(delivery.state == .sending)
        // An upload that started before the save does not count.
        exports.export(DateInterval(start: Date(timeIntervalSince1970: 999), duration: 2))
        await settle()
        #expect(delivery.state == .sending)
        timeout.release()
        await settle()
        #expect(delivery.state == .notSent)
        exports.export(DateInterval(start: Date(timeIntervalSince1970: 1001), duration: 1))
        await run.value
        #expect(delivery.state == .sent)
    }

    @Test("iphone-as-setup-device/the-iphone-confirms-the-hand-off-to-icloud: a confirmed upload reads handed to iCloud")
    func confirms() async {
        let exports = ScriptedExports()
        let delivery = delivery(signedIn: true, exports: exports, timeout: Gate())
        let run = Task { await delivery.run() }
        await settle()
        exports.export(DateInterval(start: Date(timeIntervalSince1970: 1000), duration: 1))
        await run.value
        #expect(delivery.state == .sent)
    }

    @Test("iphone-as-setup-device/the-iphone-says-what-to-check-when-sending-stalls: not signed in reads not sent at once")
    func notSignedIn() async {
        let exports = ScriptedExports()
        let delivery = delivery(signedIn: false, exports: exports, timeout: Gate())
        let run = Task { await delivery.run() }
        await settle()
        #expect(delivery.state == .notSignedIn)
        run.cancel()
        exports.export(DateInterval(start: Date(timeIntervalSince1970: 1000), duration: 1))
        await run.value
    }

    @Test("iphone-as-setup-device/scanning-opens-the-setup-form-on-the-iphone: the banner counts the sources already here")
    func sendingText() {
        #expect(SetupFromTV.Banner.existing(0, device: "iPad") == nil)
        #expect(SetupFromTV.Banner.existing(1, device: "iPad")?.hasPrefix("This iPad already has 1 source. It appears") == true)
        #expect(SetupFromTV.Banner.existing(3, device: "Mac")?.hasPrefix("This Mac already has 3 sources. They appear") == true)
    }
}
