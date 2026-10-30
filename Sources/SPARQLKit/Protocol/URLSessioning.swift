import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// What SPARQLKit needs from `URLSession`: send a request, get the response.
public protocol URLSessioning: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

#if canImport(FoundationNetworking)
extension URLSession: URLSessioning {
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
}
#else
extension URLSession: URLSessioning {}
#endif
