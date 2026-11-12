import Foundation
import Testing

@testable import AntennaCore

@Suite struct StalkerInputTests {
    @Test(
        "stalker-portal-source/type-the-mac-and-portal-address-the-way-your-provider-wrote-them every MAC form reads as one MAC",
        arguments: [
            "00:1A:79:12:34:56", "00-1A-79-12-34-56", "001A79123456", "00:1a:79:12:34:56", "001a79123456", "  00:1A:79:12:34:56 ",
            "\t00-1a-79-12-34-56\n",
        ])
    func macForms(typed: String) throws {
        let mac = try #require(MACAddress(typed))
        #expect(mac.text == "00:1A:79:12:34:56")
    }

    @Test(
        "stalker-portal-source/type-the-mac-and-portal-address-the-way-your-provider-wrote-them malformed MACs are turned down",
        arguments: [
            "", "00:1A:79:12:34", "00:1A:79:12:34:56:78", "00:1A:79:12:34:5G", "001A7912345", "001A791234567", "00:1A-79:12:34:56",
            "001:A79:12:34:56", "00 1A 79 12 34 56", "ZZ:ZZ:ZZ:ZZ:ZZ:ZZ", "00:1A:79:12:34:56x",
        ])
    func macRejected(typed: String) {
        #expect(MACAddress(typed) == nil)
    }

    @Test(
        "stalker-portal-source/type-the-mac-and-portal-address-the-way-your-provider-wrote-them portal addresses are tidied",
        arguments: [
            ("http://p.example/c/", "http://p.example"),
            ("http://p.example/c", "http://p.example"),
            ("HTTP://P.Example/", "http://p.example"),
            ("http://p.example", "http://p.example"),
            ("  http://p.example/c/  ", "http://p.example"),
            ("http://p.example:8080/stalker_portal/c/", "http://p.example:8080/stalker_portal"),
            ("https://user:pw@p.example/c/?x=1#frag", "https://p.example"),
            ("http://[::1]:8080/c/", "http://[::1]:8080"),
        ])
    func portalForms(typed: String, expected: String) throws {
        let portal = try #require(StalkerPortal(typed))
        #expect(portal.url.absoluteString == expected)
    }

    @Test(
        "stalker-portal-source/type-the-mac-and-portal-address-the-way-your-provider-wrote-them portal addresses without http or https are turned down",
        arguments: ["p.example/c/", "ftp://p.example/c/", "http:///c/", "", "p.example"])
    func portalRejected(typed: String) {
        #expect(StalkerPortal(typed) == nil)
    }

    @Test("stalker-portal-source/connect-with-the-portal-address-you-were-given the source prints as the portal's host name")
    func portalPrintsHost() throws {
        let portal = try #require(StalkerPortal("http://P.Example:8080/stalker_portal/c/"))
        #expect("\(portal)" == "p.example")
        #expect(String(reflecting: portal) == "p.example")
    }
}

@Suite struct StalkerIdentityTests {
    @Test("MD5 and SHA-256 match the published test vectors")
    func digestVectors() {
        #expect(Digest.hex(Digest.md5([])) == "D41D8CD98F00B204E9800998ECF8427E")
        #expect(Digest.hex(Digest.md5(Array("abc".utf8))) == "900150983CD24FB0D6963F7D28E17F72")
        #expect(
            Digest.hex(Digest.md5(Array("12345678901234567890123456789012345678901234567890123456789012345678901234567890".utf8)))
                == "57EDF4A22BE3C955AC49DA2E2107B67A")
        #expect(Digest.hex(Digest.sha256([])) == "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855")
        #expect(Digest.hex(Digest.sha256(Array("abc".utf8))) == "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD")
        #expect(
            Digest.hex(Digest.sha256(Array("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8)))
                == "248D6A61D20638B8E5C026930C3E6039A33CE45964FF2167F6ECEDD419DB06C1")
    }

    @Test("stalker-portal-source/portals-that-remember-your-device-still-let-you-in the identity matches what other players send")
    func identity() throws {
        let identity = StalkerIdentity(mac: try #require(MACAddress("00:1a:79:12:34:56")))
        #expect(identity.serialNumber == "2213785DC6113")
        #expect(identity.deviceID == "667094E7E8FF0347F6EC27A8E8115BE76E2AA9CD5C8F13C6FA00BCEDFAC02B41")
        #expect(identity.signature == "922F69DECA50A1E4883CDB6AF9A57D86B2C82BE460AE9AFCAF2B421C715A0D1B")
    }

    @Test("stalker-portal-source/secrets-never-show-up-in-messages-or-logs MAC, identity and credentials print without secrets")
    func printing() throws {
        let mac = try #require(MACAddress("00:1A:79:12:34:56"))
        let identity = StalkerIdentity(mac: mac)
        let portal = try #require(StalkerPortal("http://p.example:8080/stalker_portal/c/"))
        let credentials = StalkerCredentials(portal: portal, mac: mac, password: "pw-9b2a", login: "alice-7f3e")
        let client = StalkerClient(credentials: credentials)
        var dumped = ""
        dump(credentials, to: &dumped)
        dump(identity, to: &dumped)
        dump(mac, to: &dumped)
        let printed = [
            "\(mac)", String(reflecting: mac), "\(identity)", String(reflecting: identity),
            "\(credentials)", String(reflecting: credentials),
            "\(client)", String(reflecting: client), dumped,
        ].joined(separator: "\n")
        for secret in mac.spellings + ["pw-9b2a", "alice-7f3e", "8080", "stalker_portal", identity.serialNumber, identity.deviceID] {
            #expect(!printed.contains(secret), "printed \(secret)")
        }
        #expect("\(credentials)" == "p.example")
    }
}
