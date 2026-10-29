import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// How a client authenticates to an endpoint.
public struct EndpointAuthentication: Sendable {
    public enum Scheme: Sendable {
        case bearer(token: String)
        case basic(username: String, password: String)
    }

    public let scheme: Scheme

    public init(scheme: Scheme) {
        self.scheme = scheme
    }
}

/// The HTTP plumbing both protocol clients share: headers, authentication,
/// form encoding and status handling.
struct SPARQLHTTPTransport: Sendable {
    let defaultHeaders: [String: String]
    let authentication: EndpointAuthentication?
    let session: any URLSessioning

    func applyHeaders(to request: inout URLRequest) throws {
        for (header, value) in defaultHeaders {
            try validateHeader(name: header, value: value)
            request.setValue(value, forHTTPHeaderField: header)
        }
        guard let authentication else { return }
        let value: String
        switch authentication.scheme {
        case .bearer(let token):
            value = "Bearer " + token
        case .basic(let username, let password):
            value = "Basic " + Data((username + ":" + password).utf8).base64EncodedString()
        }
        try validateHeader(name: "Authorization", value: value)
        request.setValue(value, forHTTPHeaderField: "Authorization")
    }

    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SPARQLError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw SPARQLError.httpStatus(http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return (data, http)
    }

    /// An `application/x-www-form-urlencoded` body.
    func formURLEncoded(_ pairs: [(String, String)]) -> Data {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        let encoded = pairs
            .map { $0.0 + "=" + ($0.1.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.1) }
            .joined(separator: "&")
        return Data(encoded.utf8)
    }

    private func validateHeader(name: String, value: String) throws {
        func invalid(_ text: String) -> Bool {
            text.unicodeScalars.contains { $0 == "\r" || $0 == "\n" || ($0.value < 0x20 && $0 != "\t") }
        }
        if invalid(name) || invalid(value) {
            throw SPARQLError.invalidRequest("HTTP header names/values must not contain control characters.")
        }
    }
}
