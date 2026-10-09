import Foundation
import Testing
@testable import Fuego

struct FilterPolicyTests {

    @Test(arguments: [
        ("reddit.com", "reddit.com"),
        ("  Reddit.COM ", "reddit.com"),
        ("https://www.reddit.com/r/all?x=1", "reddit.com"),
        ("http://news.ycombinator.com:8080/", "news.ycombinator.com"),
        ("youtube.com.", "youtube.com"),
    ])
    func normalizesUserInput(input: String, expected: String) {
        #expect(FilterPolicy.normalizedDomain(input) == expected)
    }

    @Test(arguments: ["", "reddit", "not a domain.com", "a..com", "https://", "exa_mple.com"])
    func rejectsInvalidDomains(input: String) {
        #expect(FilterPolicy.normalizedDomain(input) == nil)
    }

    @Test func blocksDomainAndSubdomains() {
        let policy = FilterPolicy(blockedDomains: ["reddit.com"], blockUntil: .distantFuture)
        #expect(policy.blocks(host: "reddit.com"))
        #expect(policy.blocks(host: "www.reddit.com"))
        #expect(policy.blocks(host: "old.Reddit.com."))
        #expect(!policy.blocks(host: "notreddit.com"))
        #expect(!policy.blocks(host: "reddit.com.evil.net"))
        #expect(!policy.blocks(host: ""))
    }

    @Test func isActiveOnlyWithDomainsAndAFutureDeadline() {
        let now = Date()
        #expect(!FilterPolicy.off.isActive(at: now))
        #expect(!FilterPolicy(blockedDomains: [], blockUntil: .distantFuture).isActive(at: now))
        #expect(!FilterPolicy(blockedDomains: ["x.com"], blockUntil: nil).isActive(at: now))
        #expect(!FilterPolicy(blockedDomains: ["x.com"], blockUntil: now.addingTimeInterval(-1)).isActive(at: now))
        #expect(FilterPolicy(blockedDomains: ["x.com"], blockUntil: now.addingTimeInterval(60)).isActive(at: now))
    }

    @Test func roundTripsThroughVendorConfiguration() {
        let policy = FilterPolicy(
            blockedDomains: ["reddit.com", "x.com"],
            blockUntil: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(FilterPolicy(vendorConfiguration: policy.vendorConfiguration) == policy)
        #expect(FilterPolicy(vendorConfiguration: FilterPolicy.off.vendorConfiguration) == .off)
        #expect(FilterPolicy(vendorConfiguration: nil) == .off)
    }
}

struct HostSnifferTests {

    /// A ClientHello captured from `curl https://www.example.com`.
    static let curlClientHello = Data(base64Encoded: "FgMBAUABAAE8AwNfxBniaLzc2KpfjxZ1H99Xbot80PgdE1oArgB4MFT9YyA262BumwSG6oAKIrfhCrLISTF5MQ+RVdL7Sowqm/i1ZQBiEwMTAhMBzKnMqMyqwDDALMAowCTAFMAKAJ8AawA5/4UAxACIAIEAnQA9ADUAwACEwC/AK8AnwCPAE8AJAJ4AZwAzAL4ARQCcADwALwC6AEHAEcAHAAUABMASwAgAFgAKAP8BAACRACsACQgDBAMDAwIDAQAzACYAJAAdACAWsbxV7uFsPXiphrn2NgJH0ovtDPb5QFTdGhzXRoz4VwAAABQAEgAAD3d3dy5leGFtcGxlLmNvbQALAAIBAAAKAAoACAAdABcAGAAZAA0AGAAWCAYGAQYDCAUFAQUDCAQEAQQDAgECAwAQAA4ADAJoMghodHRwLzEuMQ==")!

    @Test func readsSNIFromRealClientHello() {
        #expect(HostSniffer.sniff(Self.curlClientHello) == .host("www.example.com"))
    }

    @Test func asksForTheRestOfATruncatedClientHello() {
        let hello = Self.curlClientHello
        #expect(HostSniffer.sniff(hello.prefix(3)) == .needBytes(5))
        #expect(HostSniffer.sniff(hello.prefix(100)) == .needBytes(hello.count))
    }

    @Test func readsSNIAfterLargeExtensions() {
        // Chrome shuffles extensions and sends a ~1.2KB post-quantum key share, so SNI can come late.
        let hello = makeClientHello(serverName: "youtube.com", paddingBefore: 1500)
        #expect(HostSniffer.sniff(hello) == .host("youtube.com"))
    }

    @Test func readsHTTPHostHeader() {
        let request = Data("GET / HTTP/1.1\r\nUser-Agent: x\r\nHost: Example.com:8080\r\n\r\n".utf8)
        #expect(HostSniffer.sniff(request) == .host("example.com"))
    }

    @Test func waitsForCompleteHTTPHeaders() {
        let partial = Data("GET / HTTP/1.1\r\nHost: exa".utf8)
        guard case .needBytes(let count) = HostSniffer.sniff(partial) else {
            Issue.record("expected needBytes")
            return
        }
        #expect(count > partial.count)
    }

    @Test func ignoresOtherProtocols() {
        #expect(HostSniffer.sniff(Data("SSH-2.0-OpenSSH_9.6\r\n".utf8)) == .unknown)
        #expect(HostSniffer.sniff(Data([0x00, 0x01, 0x02])) == .unknown)
        #expect(HostSniffer.sniff(Data([0x16, 0x03, 0x01, 0x00, 0x05, 0x02, 0, 0, 0, 0])) == .unknown)
    }

    /// Builds a minimal TLS 1.2-style ClientHello with an optional padding extension before SNI.
    private func makeClientHello(serverName: String, paddingBefore: Int) -> Data {
        func u16(_ value: Int) -> [UInt8] { [UInt8(value >> 8), UInt8(value & 0xff)] }
        let name = Array(serverName.utf8)

        // Built step by step: long `+` chains of array literals time out older type checkers.
        var extensions: [UInt8] = []
        extensions += u16(0x0015)  // padding
        extensions += u16(paddingBefore)
        extensions += [UInt8](repeating: 0, count: paddingBefore)
        extensions += u16(0x0000)  // server_name
        extensions += u16(name.count + 5)
        extensions += u16(name.count + 3)
        extensions += [0x00]
        extensions += u16(name.count)
        extensions += name

        var body: [UInt8] = [0x03, 0x03]  // client version
        body += [UInt8](repeating: 7, count: 32)  // random
        body += [0x00]  // session ID
        body += u16(2)
        body += [0x13, 0x01]  // cipher suites
        body += [0x01, 0x00]  // compression
        body += u16(extensions.count)
        body += extensions

        var handshake: [UInt8] = [0x01, 0x00]
        handshake += u16(body.count)
        handshake += body

        var record: [UInt8] = [0x16, 0x03, 0x01]
        record += u16(handshake.count)
        record += handshake
        return Data(record)
    }
}
