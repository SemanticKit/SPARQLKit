import Foundation

/// Encodes name–value pairs as `application/x-www-form-urlencoded`, the
/// format of a SPARQL Protocol POST body and of every request URL's query
/// string (SPARQL 1.2 Protocol §2.1.2, §2.1.3, §2.2.1; Graph Store HTTP
/// Protocol §4.2).
///
/// Only the RFC 3986 unreserved characters are written as they are; every
/// other UTF-8 byte is percent-encoded. So a `+` in a query (`foaf:knows+`,
/// `?x + 1`) or in an IRI is sent as `%2B` and never read back as the space
/// that form decoding makes of a bare `+`.
struct FormURLEncoder: Sendable {
    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    /// The encoded pairs, joined with `&`. A pair with no value is written
    /// as its name alone (`?default`).
    func encode(_ pairs: [(name: String, value: String?)]) -> String {
        pairs.map { pair in
            let name = escape(pair.name)
            return pair.value.map { name + "=" + escape($0) } ?? name
        }.joined(separator: "&")
    }

    private func escape(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: Self.unreserved) ?? text
    }
}
