import Foundation

/// Recovers the destination hostname from the first bytes a client sends.
///
/// Browsers like Chrome and Firefox resolve DNS themselves and connect by IP address,
/// so the filter often gets no hostname for a flow. The hostname is still visible in the
/// TLS ClientHello (SNI) for HTTPS, and in the Host header for plain HTTP.
enum HostSniffer {
    enum Result: Equatable {
        case host(String)
        /// The opening message is incomplete; ask for this many bytes in total.
        case needBytes(Int)
        case unknown
    }

    /// The most bytes worth waiting for before giving up on a flow.
    static let maxPeekBytes = 16 * 1024

    static func sniff(_ data: Data) -> Result {
        let bytes = [UInt8](data)
        guard let first = bytes.first else { return .needBytes(5) }
        if first == 0x16 {
            return sniffTLS(bytes)
        }
        if first >= 0x41 && first <= 0x5A {  // 'A'...'Z', the start of an HTTP method
            return sniffHTTP(bytes)
        }
        return .unknown
    }

    // MARK: - TLS

    private static func sniffTLS(_ bytes: [UInt8]) -> Result {
        // Record header: type(1) version(2) length(2)
        guard bytes.count >= 5 else { return .needBytes(5) }
        let recordLength = Int(bytes[3]) << 8 | Int(bytes[4])
        let recordEnd = 5 + recordLength
        guard recordEnd <= maxPeekBytes else { return .unknown }
        guard bytes.count >= recordEnd else { return .needBytes(recordEnd) }

        var reader = ByteReader(bytes: bytes, position: 5, end: recordEnd)
        guard reader.u8() == 0x01,  // ClientHello
            reader.skip(3),  // handshake length
            reader.skip(2 + 32),  // client version, random
            let sessionIDLength = reader.u8(), reader.skip(Int(sessionIDLength)),
            let cipherSuitesLength = reader.u16(), reader.skip(cipherSuitesLength),
            let compressionLength = reader.u8(), reader.skip(Int(compressionLength)),
            let extensionsLength = reader.u16()
        else {
            return .unknown
        }

        let extensionsEnd = min(reader.position + extensionsLength, recordEnd)
        while reader.position + 4 <= extensionsEnd {
            guard let type = reader.u16(), let length = reader.u16() else { return .unknown }
            guard type == 0x0000 else {  // server_name
                guard reader.skip(length) else { return .unknown }
                continue
            }
            // server_name_list length(2), then entries of name_type(1) length(2) name
            guard reader.skip(2), reader.u8() == 0x00, let nameLength = reader.u16(),
                let name = reader.take(nameLength),
                let host = String(bytes: name, encoding: .ascii), !host.isEmpty
            else {
                return .unknown
            }
            return .host(host.lowercased())
        }
        return .unknown
    }

    // MARK: - HTTP

    private static func sniffHTTP(_ bytes: [UInt8]) -> Result {
        let methods = ["GET ", "POST ", "HEAD ", "PUT ", "DELETE ", "OPTIONS ", "PATCH ", "CONNECT "]
        let prefix = String(decoding: bytes.prefix(8), as: UTF8.self)
        guard methods.contains(where: { prefix.hasPrefix($0) || $0.hasPrefix(prefix) }) else {
            return .unknown
        }

        let text = String(decoding: bytes.prefix(maxPeekBytes), as: UTF8.self)
        guard let headersEnd = text.range(of: "\r\n\r\n") else {
            return bytes.count < maxPeekBytes ? .needBytes(min(bytes.count * 2, maxPeekBytes)) : .unknown
        }
        for line in text[..<headersEnd.lowerBound].split(separator: "\r\n").dropFirst() {
            guard let colon = line.firstIndex(of: ":"),
                line[..<colon].trimmingCharacters(in: .whitespaces).lowercased() == "host"
            else { continue }
            var host = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if !host.hasPrefix("["), let portStart = host.firstIndex(of: ":") {
                host = String(host[..<portStart])
            }
            return host.isEmpty ? .unknown : .host(host.lowercased())
        }
        return .unknown
    }
}

private struct ByteReader {
    let bytes: [UInt8]
    var position: Int
    let end: Int

    mutating func u8() -> UInt8? {
        guard position + 1 <= end else { return nil }
        defer { position += 1 }
        return bytes[position]
    }

    mutating func u16() -> Int? {
        guard position + 2 <= end else { return nil }
        defer { position += 2 }
        return Int(bytes[position]) << 8 | Int(bytes[position + 1])
    }

    mutating func skip(_ count: Int) -> Bool {
        guard count >= 0, position + count <= end else { return false }
        position += count
        return true
    }

    mutating func take(_ count: Int) -> ArraySlice<UInt8>? {
        guard position + count <= end else { return nil }
        defer { position += count }
        return bytes[position..<position + count]
    }
}
