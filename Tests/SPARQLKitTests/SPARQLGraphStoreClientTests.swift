import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import IRIKit
import RDFCore
import RDFFormats
import Testing
@testable import SPARQLKit

@Suite("Graph Store Protocol client", .tags(.protocol))
struct SPARQLGraphStoreClientTests {
    let graphStore = URL(string: "https://example.org/graphs")!
    let named: IRI = "https://example.org/g"
    let triple = Graph.Element(
        subject: .iri("http://example.org/s"),
        predicate: "http://example.org/p",
        object: .iri("http://example.org/o")
    )

    func client(_ session: MockSession, headers: [String: String] = [:], authentication: EndpointAuthentication? = nil) -> SPARQLGraphStoreClient {
        SPARQLGraphStoreClient(
            configuration: SPARQLGraphStoreConfiguration(graphStoreURL: graphStore, defaultHeaders: headers, authentication: authentication),
            session: session
        )
    }

    @Test("GET of the default graph decodes the graph it returns")
    func getDefaultGraph() async throws {
        let session = MockSession(body: "<http://example.org/s> <http://example.org/p> <http://example.org/o> .")
        let graph = try await client(
            session,
            headers: ["X-Client": "SPARQLKit"],
            authentication: EndpointAuthentication(scheme: .bearer(token: "token123"))
        ).getGraph(.defaultGraph, accept: .turtle, conditional: SPARQLConditionalRequest(ifMatch: "\"abc\""))

        #expect(graph == [triple])
        let request = try #require(session.lastRequest)
        #expect(request.url?.absoluteString == "https://example.org/graphs?default")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "text/turtle")
        #expect(request.value(forHTTPHeaderField: "If-Match") == "\"abc\"")
        #expect(request.value(forHTTPHeaderField: "X-Client") == "SPARQLKit")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token123")
    }

    @Test("PUT of a named graph sends its triples as N-Triples")
    func putNamedGraph() async throws {
        let session = MockSession()
        _ = try await client(session).putGraph([triple], graph: .named(named), conditional: SPARQLConditionalRequest(ifNoneMatch: "*"))

        let request = try #require(session.lastRequest)
        #expect(request.url?.absoluteString == "https://example.org/graphs?graph=https%3A%2F%2Fexample.org%2Fg")
        #expect(request.httpMethod == "PUT")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/n-triples")
        #expect(request.value(forHTTPHeaderField: "If-None-Match") == "*")
        #expect(request.bodyText == "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n")
    }

    @Test("A named graph IRI is percent-encoded in the graph parameter, '+' included", .tags(.security))
    func namedGraphIsPercentEncoded() async throws {
        let session = MockSession()
        _ = try await client(session).deleteGraph(.named("https://example.org/g?a=1&b=c+d"))

        #expect(session.lastRequest?.url?.absoluteString
            == "https://example.org/graphs?graph=https%3A%2F%2Fexample.org%2Fg%3Fa%3D1%26b%3Dc%2Bd")
    }

    @Test("POST to the default graph and to the store")
    func postGraph() async throws {
        let session = MockSession()
        _ = try await client(session).postGraph([triple])
        #expect(session.lastRequest?.url?.absoluteString == "https://example.org/graphs?default")
        #expect(session.lastRequest?.httpMethod == "POST")

        _ = try await client(session).postGraph([triple], graph: .service)
        #expect(session.lastRequest?.url?.absoluteString == "https://example.org/graphs")
    }

    @Test("DELETE and HEAD of a named graph")
    func deleteAndHead() async throws {
        let session = MockSession()
        _ = try await client(session).deleteGraph(.named(named))
        #expect(session.lastRequest?.httpMethod == "DELETE")
        #expect(session.lastRequest?.url?.absoluteString == "https://example.org/graphs?graph=https%3A%2F%2Fexample.org%2Fg")

        let response = try await client(session).headGraph(
            .named(named),
            conditional: SPARQLConditionalRequest(ifModifiedSince: "Mon, 01 Jan 2024 00:00:00 GMT")
        )
        #expect(response.statusCode == 200)
        #expect(session.lastRequest?.httpMethod == "HEAD")
        #expect(session.lastRequest?.value(forHTTPHeaderField: "If-Modified-Since") == "Mon, 01 Jan 2024 00:00:00 GMT")
    }

    @Test("Every conditional header is sent")
    func conditionalHeaders() async throws {
        let session = MockSession()
        _ = try await client(session).deleteGraph(conditional: SPARQLConditionalRequest(
            ifMatch: "\"etag-1\"",
            ifNoneMatch: "\"etag-2\"",
            ifUnmodifiedSince: "Mon, 01 Jan 2024 00:00:00 GMT",
            ifModifiedSince: "Tue, 02 Jan 2024 00:00:00 GMT"
        ))
        let request = try #require(session.lastRequest)
        #expect(request.value(forHTTPHeaderField: "If-Match") == "\"etag-1\"")
        #expect(request.value(forHTTPHeaderField: "If-None-Match") == "\"etag-2\"")
        #expect(request.value(forHTTPHeaderField: "If-Unmodified-Since") == "Mon, 01 Jan 2024 00:00:00 GMT")
        #expect(request.value(forHTTPHeaderField: "If-Modified-Since") == "Tue, 02 Jan 2024 00:00:00 GMT")
    }

    @Test("HTTP failures reach the caller")
    func httpFailures() async {
        await #expect(throws: SPARQLError.httpStatus(409, body: "conflict")) {
            _ = try await client(MockSession(statusCode: 409, body: "conflict")).deleteGraph()
        }
        await #expect(throws: SPARQLError.httpStatus(404, body: "")) {
            _ = try await client(MockSession(statusCode: 404, body: "")).headGraph(.named(named))
        }
    }

    @Test("Header values with control characters are refused")
    func refusesControlCharacters() async {
        await #expect(throws: SPARQLError.invalidRequest("HTTP header names/values must not contain control characters.")) {
            _ = try await client(MockSession(), headers: ["X-Bad": "a\r\nb"]).getGraph()
        }
    }

    @Test(
        "Conditional header values with control characters are refused before sending",
        .tags(.security),
        arguments: [
            SPARQLConditionalRequest(ifMatch: "\"a\"\r\nX-Injected: 1"),
            SPARQLConditionalRequest(ifNoneMatch: "*\n"),
            SPARQLConditionalRequest(ifUnmodifiedSince: "Mon\r"),
            SPARQLConditionalRequest(ifModifiedSince: "Tue\u{0}")
        ]
    )
    func refusesControlCharactersInConditionalHeaders(conditional: SPARQLConditionalRequest) async {
        let session = MockSession()
        await #expect(throws: SPARQLError.invalidRequest("HTTP header names/values must not contain control characters.")) {
            _ = try await client(session).deleteGraph(conditional: conditional)
        }
        #expect(session.requests.isEmpty)
    }

    @Test("Relative IRIs in a returned graph resolve against the graph's URL")
    func relativeIRIsResolveAgainstRetrievalURL() async throws {
        let session = MockSession(body: "<#a> <#b> <c> .")
        #expect(try await client(session).getGraph(.defaultGraph) == [Graph.Element(
            subject: .iri("https://example.org/graphs?default#a"),
            predicate: "https://example.org/graphs?default#b",
            object: .iri("https://example.org/c")
        )])
        #expect(try await client(session).getGraph(.named(named), accept: .turtle) == [Graph.Element(
            subject: .iri("https://example.org/graphs?graph=https%3A%2F%2Fexample.org%2Fg#a"),
            predicate: "https://example.org/graphs?graph=https%3A%2F%2Fexample.org%2Fg#b",
            object: .iri("https://example.org/c")
        )])
    }
}
