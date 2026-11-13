import Foundation
import Security

/// Where source credentials are kept. `CredentialStore` is the only
/// production conformance; tests substitute one that fails on purpose.
protocol CredentialStoring: Sendable {
    func save(_ credential: CredentialStore.Credential, for key: String) throws
    func load(for key: String) throws -> CredentialStore.Credential?
    func delete(for key: String) throws
}

/// Keychain wrapper for source credentials. Items are marked synchronizable so
/// iCloud Keychain carries them between the user's devices without us ever
/// seeing them. Playlist URLs live in SwiftData; secrets live here.
///
/// Items go to the access group both apps share, so the Apple TV app reads a
/// login the iPhone app saved (source-management/logins-are-shared-between-the-apps).
/// A login an earlier build left in the app's own group moves there on its
/// first read (source-management/logins-saved-by-an-earlier-version-move-to-the-shared-place).
struct CredentialStore: CredentialStoring {
    /// For a Stalker source `username` holds the MAC and `login` the
    /// optional portal login. Items saved without `login` decode with nil.
    struct Credential: Codable, Sendable, Equatable {
        var username: String
        var password: String
        var login: String?

        init(username: String, password: String, login: String? = nil) {
            self.username = username
            self.password = password
            self.login = login
        }
    }

    enum StoreError: Error, Equatable { case unexpectedStatus(OSStatus), encoding }

    static let sourcesService = "se.codecrave.antenna.sources"
    static let groupInfoKey = "AntennaKeychainGroup"

    /// The shared access group from the app's Info.plist, or nil in a build
    /// that is not signed and so carries no Keychain entitlement.
    static let appSharedGroup: String? = {
        guard let group = Bundle.main.object(forInfoDictionaryKey: groupInfoKey) as? String, !group.isEmpty else { return nil }
        return group
    }()

    /// The Keychain service every item is stored under. The app uses
    /// `sourcesService`; tests pass their own so they never share items with it.
    let service: String
    /// The access group logins are written to, or nil for the app's default group.
    let sharedGroup: String?
    let keychain: any KeychainItems

    init(
        service: String = CredentialStore.sourcesService, sharedGroup: String? = CredentialStore.appSharedGroup,
        keychain: any KeychainItems = SystemKeychain()
    ) {
        self.service = service
        self.sharedGroup = sharedGroup
        self.keychain = keychain
    }

    /// Writes to the shared group and removes copies in other groups. When
    /// the app lacks the shared group's entitlement, writes to its default group.
    func save(_ credential: Credential, for key: String) throws {
        let data = try JSONEncoder().encode(credential)
        if let sharedGroup {
            do {
                try keychain.write(data, service: service, account: key, group: sharedGroup)
                removeCopies(of: key, outside: sharedGroup)
                return
            } catch StoreError.unexpectedStatus(errSecMissingEntitlement) {
                // Fall through to the default group.
            }
        }
        try keychain.write(data, service: service, account: key, group: nil)
    }

    /// Reads the login from any group this app can open. A copy outside the
    /// shared group is moved there; if the move fails the copy is still
    /// returned and the next read tries again.
    func load(for key: String) throws -> Credential? {
        let groups = try keychain.groups(service: service, account: key)
        if let sharedGroup, groups.contains(sharedGroup) {
            guard let data = try keychain.data(service: service, account: key, group: sharedGroup) else { return nil }
            let credential = try JSONDecoder().decode(Credential.self, from: data)
            removeCopies(of: key, outside: sharedGroup)
            return credential
        }
        guard let group = groups.first, let data = try keychain.data(service: service, account: key, group: group) else { return nil }
        let credential = try JSONDecoder().decode(Credential.self, from: data)
        // An item whose group the Keychain did not report is used where it is.
        if group != nil, let sharedGroup, (try? keychain.write(data, service: service, account: key, group: sharedGroup)) != nil {
            removeCopies(of: key, outside: sharedGroup)
        }
        return credential
    }

    /// Removes the login from every group this app can open.
    func delete(for key: String) throws {
        try keychain.delete(service: service, account: key, group: nil)
    }

    private func removeCopies(of key: String, outside sharedGroup: String) {
        let groups = (try? keychain.groups(service: service, account: key)) ?? []
        for case let group? in groups where group != sharedGroup {
            try? keychain.delete(service: service, account: key, group: group)
        }
    }
}

/// The Keychain calls `CredentialStore` makes, one synchronizable generic
/// password per service and account. `SystemKeychain` is the production
/// conformance; tests stand in a Keychain with several access groups.
protocol KeychainItems: Sendable {
    /// The access groups holding an item, among those this app can open.
    /// Nil stands for an item whose group the Keychain did not report.
    func groups(service: String, account: String) throws -> [String?]
    /// The item's data in `group`, or in any group when nil; nil when there is none.
    func data(service: String, account: String, group: String?) throws -> Data?
    /// Updates the item in `group`, or adds it there. A nil group updates the
    /// item wherever it is, or adds it to the app's default group.
    func write(_ data: Data, service: String, account: String, group: String?) throws
    /// Deletes the item from `group`, or from every group when nil. Deleting
    /// an item that is not there is not an error.
    func delete(service: String, account: String, group: String?) throws
}

/// The device's Keychain.
struct SystemKeychain: KeychainItems {
    func groups(service: String, account: String) throws -> [String?] {
        var query = Self.query(service: service, account: account, group: nil)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let found = items as? [[String: Any]] else {
            throw CredentialStore.StoreError.unexpectedStatus(status)
        }
        return found.map { $0[kSecAttrAccessGroup as String] as? String }
    }

    func data(service: String, account: String, group: String?) throws -> Data? {
        var query = Self.query(service: service, account: account, group: group)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw CredentialStore.StoreError.unexpectedStatus(status) }
        return data
    }

    func write(_ data: Data, service: String, account: String, group: String?) throws {
        let query = Self.query(service: service, account: account, group: group)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw CredentialStore.StoreError.unexpectedStatus(addStatus) }
        } else if status != errSecSuccess {
            throw CredentialStore.StoreError.unexpectedStatus(status)
        }
    }

    func delete(service: String, account: String, group: String?) throws {
        let status = SecItemDelete(Self.query(service: service, account: account, group: group) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CredentialStore.StoreError.unexpectedStatus(status) }
    }

    private static func query(service: String, account: String, group: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: true,
        ]
        if let group { query[kSecAttrAccessGroup as String] = group }
        return query
    }
}
