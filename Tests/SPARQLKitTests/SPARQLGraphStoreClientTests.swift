import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import SPARQLKit

@Test
func getDefaultGraphBuildsExpectedRequest() async throws {
    let session = GraphStoreMockSession(statusCode: 200, body: "ok")
    let client = SPARQLGraphStoreClient(
        configuration: SPARQLGraphStoreConfiguration(
            graphStoreURL: URL(string: "https://example.org/graphs")!,
            defaultHeaders: ["X-Client": "SPARQLKit"],
            authentication: EndpointAuthentication(scheme: .bearer(token: "token123"))
        ),
        session: session
    )

    _ = try await client.getGraph(
        graph: .defaultGraph,
        accept: .turtle,
        conditional: SPARQLConditionalRequest(ifMatch: "\"abc\"")
    )

    let request = try #require(session.lastRequest)
    let url = try #require(request.url?.absoluteString)
    #expect(url.contains("default"))
    #expect(request.httpMethod == "GET")
    #expect(request.value(forHTTPHeaderField: "Accept") == SPARQLGraphAccept.turtle.rawValue)
    #expect(request.value(forHTTPHeaderField: "If-Match") == "\"abc\"")
    #expect(request.value(forHTTPHeaderField: "X-Client") == "SPARQLKit")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token123")
}

@Test
func putNamedGraphBuildsExpectedRequest() async throws {
    let session = GraphStoreMockSession(statusCode: 200, body: "ok")
    let client = SPARQLGraphStoreClient(
        configuration: SPARQLGraphStoreConfiguration(graphStoreURL: URL(string: "https://example.org/graphs")!),
        session: session
    )

    let turtle = Data("<s> <p> <o> .".utf8)
    _ = try await client.putGraph(
        turtle,
        contentType: "text/turtle",
        graph: .named("https://example.org/g"),
        conditional: SPARQLConditionalRequest(ifNoneMatch: "*")
    )

    let request = try #require(session.lastRequest)
    let url = try #require(request.url?.absoluteString)
    #expect(url.contains("graph=https://example.org/g"))
    #expect(request.httpMethod == "PUT")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "text/turtle")
    #expect(request.value(forHTTPHeaderField: "If-None-Match") == "*")
    #expect(request.httpBody == turtle)
}

@Test
func postDefaultGraphBuildsExpectedRequest() async throws {
    let session = GraphStoreMockSession(statusCode: 200, body: "ok")
    let client = SPARQLGraphStoreClient(
        configuration: SPARQLGraphStoreConfiguration(graphStoreURL: URL(string: "https://example.org/graphs")!),
        session: session
    )

    let turtle = Data("<s> <p> <o> .".utf8)
    _ = try await client.postGraph(
        turtle,
        contentType: "text/turtle",
        graph: .defaultGraph
    )

    let request = try #require(session.lastRequest)
    let url = try #require(request.url?.absoluteString)
    #expect(url.contains("default"))
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "text/turtle")
    #expect(request.httpBody == turtle)
}

@Test
func deleteGraphMapsHTTPFailures() async throws {
    let session = GraphStoreMockSession(statusCode: 409, body: "conflict")
    let client = SPARQLGraphStoreClient(
        configuration: SPARQLGraphStoreConfiguration(graphStoreURL: URL(string: "https://example.org/graphs")!),
        session: session
    )

    await #expect(throws: SPARQLError.httpStatus(409, body: "conflict")) {
        _ = try await client.deleteGraph(graph: .named("https://example.org/g"))
    }
}

@Test
func deleteNamedGraphBuildsExpectedRequest() async throws {
    let session = GraphStoreMockSession(statusCode: 200, body: "ok")
    let client = SPARQLGraphStoreClient(
        configuration: SPARQLGraphStoreConfiguration(graphStoreURL: URL(string: "https://example.org/graphs")!),
        session: session
    )

    _ = try await client.deleteGraph(graph: .named("https://example.org/g"))
    let request = try #require(session.lastRequest)
    let url = try #require(request.url?.absoluteString)
    #expect(url.contains("graph=https://example.org/g"))
    #expect(request.httpMethod == "DELETE")
}

@Test
func headGraphBuildsExpectedRequest() async throws {
    let session = GraphStoreMockSession(statusCode: 200, body: "")
    let client = SPARQLGraphStoreClient(
        configuration: SPARQLGraphStoreConfiguration(graphStoreURL: URL(string: "https://example.org/graphs")!),
        session: session
    )

    let response = try await client.headGraph(
        graph: .named("https://example.org/g"),
        conditional: SPARQLConditionalRequest(ifModifiedSince: "Mon, 01 Jan 2024 00:00:00 GMT")
    )

    let request = try #require(session.lastRequest)
    let url = try #require(request.url?.absoluteString)
    #expect(url.contains("graph=https://example.org/g"))
    #expect(request.httpMethod == "HEAD")
    #expect(request.value(forHTTPHeaderField: "If-Modified-Since") == "Mon, 01 Jan 2024 00:00:00 GMT")
    #expect(response.statusCode == 200)
}

@Test
func headGraphMapsHTTPFailures() async throws {
    let session = GraphStoreMockSession(statusCode: 404, body: "")
    let client = SPARQLGraphStoreClient(
        configuration: SPARQLGraphStoreConfiguration(graphStoreURL: URL(string: "https://example.org/graphs")!),
        session: session
    )

    await #expect(throws: SPARQLError.httpStatus(404, body: "")) {
        _ = try await client.headGraph(graph: .named("https://example.org/missing"))
    }
}

@Test
func postGraphToServiceReferenceOmitsGraphQueryParameters() async throws {
    let session = GraphStoreMockSession(statusCode: 200, body: "ok")
    let client = SPARQLGraphStoreClient(
        configuration: SPARQLGraphStoreConfiguration(graphStoreURL: URL(string: "https://example.org/graphs")!),
        session: session
    )

    let turtle = Data("<s> <p> <o> .".utf8)
    _ = try await client.postGraph(
        turtle,
        contentType: "text/turtle",
        graph: .service
    )

    let request = try #require(session.lastRequest)
    let url = try #require(request.url?.absoluteString)
    #expect(url == "https://example.org/graphs")
    #expect(request.httpMethod == "POST")
}

@Test
func deleteGraphAppliesAllConditionalHeaders() async throws {
    let session = GraphStoreMockSession(statusCode: 200, body: "ok")
    let client = SPARQLGraphStoreClient(
        configuration: SPARQLGraphStoreConfiguration(graphStoreURL: URL(string: "https://example.org/graphs")!),
        session: session
    )

    _ = try await client.deleteGraph(
        graph: .named("https://example.org/g"),
        conditional: SPARQLConditionalRequest(
            ifMatch: "\"etag-1\"",
            ifNoneMatch: "\"etag-2\"",
            ifUnmodifiedSince: "Mon, 01 Jan 2024 00:00:00 GMT",
            ifModifiedSince: "Tue, 02 Jan 2024 00:00:00 GMT"
        )
    )

    let request = try #require(session.lastRequest)
    #expect(request.value(forHTTPHeaderField: "If-Match") == "\"etag-1\"")
    #expect(request.value(forHTTPHeaderField: "If-None-Match") == "\"etag-2\"")
    #expect(request.value(forHTTPHeaderField: "If-Unmodified-Since") == "Mon, 01 Jan 2024 00:00:00 GMT")
    #expect(request.value(forHTTPHeaderField: "If-Modified-Since") == "Tue, 02 Jan 2024 00:00:00 GMT")
}

@Test
func graphStoreRequestRejectsInvalidHeaderControlCharacters() async throws {
    let session = GraphStoreMockSession(statusCode: 200, body: "ok")
    let client = SPARQLGraphStoreClient(
        configuration: SPARQLGraphStoreConfiguration(
            graphStoreURL: URL(string: "https://example.org/graphs")!,
            defaultHeaders: ["X-Bad": "bad\rvalue"]
        ),
        session: session
    )

    await #expect(throws: SPARQLError.invalidRequest("HTTP header names/values must not contain control characters.")) {
        _ = try await client.getGraph(graph: .defaultGraph)
    }
}

private final class GraphStoreMockSession: URLSessioning, @unchecked Sendable {
    private let responseData: Data
    private let responseCode: Int
    private(set) var lastRequest: URLRequest?

    init(statusCode: Int, body: String) {
        self.responseCode = statusCode
        self.responseData = Data(body.utf8)
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        return (
            responseData,
            HTTPURLResponse(url: request.url!, statusCode: responseCode, httpVersion: nil, headerFields: nil)!
        )
    }
}
