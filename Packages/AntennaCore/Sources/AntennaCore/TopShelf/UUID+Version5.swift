import Foundation

extension UUID {
    /// A version 5 UUID: the SHA-1 of `namespace` then `name` in UTF-8, with
    /// the version and variant bits set (RFC 9562). The same inputs always
    /// give the same UUID.
    init(version5 name: String, namespace: UUID) {
        let input = withUnsafeBytes(of: namespace.uuid) { Array($0) } + Array(name.utf8)
        var hash = Array(Digest.sha1(input).prefix(16))
        hash[6] = (hash[6] & 0x0f) | 0x50
        hash[8] = (hash[8] & 0x3f) | 0x80
        self.init(
            uuid: (
                hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7],
                hash[8], hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15]
            ))
    }
}
