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
struct CredentialStore: CredentialStoring {
    struct Credential: Codable, Sendable, Equatable {
        var username: String
        var password: String
    }

    enum StoreError: Error { case unexpectedStatus(OSStatus), encoding }

    static let sourcesService = "se.codecrave.antenna.sources"

    /// The Keychain service every item is stored under. The app uses
    /// `sourcesService`; tests pass their own so they never share items with it.
    let service: String

    init(service: String = CredentialStore.sourcesService) {
        self.service = service
    }

    func save(_ credential: Credential, for key: String) throws {
        let data = try JSONEncoder().encode(credential)
        let query = baseQuery(key: key)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw StoreError.unexpectedStatus(addStatus) }
        } else if status != errSecSuccess {
            throw StoreError.unexpectedStatus(status)
        }
    }

    func load(for key: String) throws -> Credential? {
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw StoreError.unexpectedStatus(status) }
        return try JSONDecoder().decode(Credential.self, from: data)
    }

    func delete(for key: String) throws {
        let status = SecItemDelete(baseQuery(key: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw StoreError.unexpectedStatus(status) }
    }

    private func baseQuery(key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: true,
        ]
    }
}
