import AntennaCore
import Foundation
import os

/// Debug builds' lines about the Play on stores, in the `playOn` category.
/// They name the step, the error and how many devices of each kind a read
/// returned, never a device name, title, source or link. Release builds
/// write nothing.
enum PlayOnLog {
    #if DEBUG
        static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "se.codecrave.antenna", category: "playOn")
    #endif

    /// A store call that failed.
    static func failure(_ step: StaticString, _ error: any Error) {
        #if DEBUG
            let reason = (error as? PlayOnStoreError).map { "\($0)" } ?? "\(type(of: error))"
            logger.error("\(step, privacy: .public) failed: \(reason, privacy: .public)")
        #endif
    }

    /// A CloudKit error on its way to a `PlayOnStoreError`, by domain and code.
    static func cloudKit(_ error: any Error) {
        #if DEBUG
            let ns = error as NSError
            logger.error(
                "CloudKit error \(ns.domain, privacy: .public) \(ns.code, privacy: .public): \(ns.localizedDescription, privacy: .public)")
        #endif
    }

    /// What a read of the device list returned.
    static func read(_ devices: [PlayDeviceInfo]) {
        #if DEBUG
            let kinds = PlayDeviceInfo.Kind.allCases.map { kind in "\(kind.rawValue) \(devices.count { $0.kind == kind })" }
            logger.log("read devices: \(devices.count, privacy: .public) (\(kinds.joined(separator: ", "), privacy: .public))")
        #endif
    }
}
