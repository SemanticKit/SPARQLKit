import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Synchronization
@testable import SPARQLKit

/// A session that records requests and answers each with the next canned
/// response, repeating the last one.
final class MockSession: URLSessioning {
    private struct State {
        var responses: [(status: Int, body: String)]
        var requests: [URLRequest] = []
    }

    private let state: Mutex<State>
    private let error: (any Error & Sendable)?

    init(statusCode: Int = 200, body: String = "") {
        state = Mutex(State(responses: [(statusCode, body)]))
        error = nil
    }

    init(responses: [(Int, String)]) {
        state = Mutex(State(responses: responses.map { (status: $0.0, body: $0.1) }))
        error = nil
    }

    init(failingWith error: any Error & Sendable) {
        state = Mutex(State(responses: []))
        self.error = error
    }

    var requests: [URLRequest] { state.withLock { $0.requests } }
    var lastRequest: URLRequest? { requests.last }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = state.withLock { state -> (status: Int, body: String) in
            state.requests.append(request)
            let index = min(state.requests.count - 1, state.responses.count - 1)
            return index >= 0 ? state.responses[index] : (200, "")
        }
        if let error { throw error }
        let http = HTTPURLResponse(url: request.url!, statusCode: response.status, httpVersion: nil, headerFields: nil)!
        return (Data(response.body.utf8), http)
    }
}

extension URLRequest {
    /// The form body as text.
    var bodyText: String {
        httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
}
