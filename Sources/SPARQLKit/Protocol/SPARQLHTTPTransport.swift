import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import IRIKit

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
            try setHeader(header, value, on: &request)
        }
        guard let authentication else { return }
        let value: String
        switch authentication.scheme {
        case .bearer(let token):
            value = "Bearer " + token
        case .basic(let username, let password):
            value = "Basic " + Data((username + ":" + password).utf8).base64EncodedString()
        }
        try setHeader("Authorization", value, on: &request)
    }

    /// Sets a header after checking that neither its name nor its value
    /// holds a control character, so no caller-supplied text can end the
    /// header line and start another (RFC 9110 §5.5). A `nil` value sets
    /// nothing.
    func setHeader(_ name: String, _ value: String?, on request: inout URLRequest) throws {
        guard let value else { return }
        try validateHeader(name: name, value: value)
        request.setValue(value, forHTTPHeaderField: name)
    }

    /// The IRI a response body was retrieved from, which relative IRIs in it
    /// resolve against (RFC 3986 §5.1.3): the response URL after any
    /// redirect, else the request URL.
    func retrievalIRI(of response: HTTPURLResponse, for request: URLRequest) -> IRI? {
        (response.url ?? request.url).flatMap { IRI(rawValue: $0.absoluteString) }
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
