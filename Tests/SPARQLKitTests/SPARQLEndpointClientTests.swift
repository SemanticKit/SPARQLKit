import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import IRIKit
import RDFCore
import RDFFormats
import RDFKit
import Testing
@testable import SPARQLKit

@Suite("SPARQL Protocol client", .tags(.protocol))
struct SPARQLEndpointClientTests {
    let queryURL = URL(string: "https://example.org/sparql")!
    let updateURL = URL(string: "https://example.org/update")!
    let select = SPARQLSelectQuery(["s"], where: [.triple(SPARQLTriplePattern(.variable("s"), .variable("p"), .variable("o")))])
    let insertData = SPARQLUpdateOperation.insertData([
        SPARQLTriplePattern(.iri("http://example.org/s"), .property(Foaf.knows.sparql), .iri("http://example.org/o"))
    ])

    func client(_ session: MockSession = MockSession(), update: Bool = true, headers: [String: String] = [:]) -> SPARQLEndpointClient {
        SPARQLEndpointClient(
            configuration: SPARQLEndpointConfiguration(
                queryURL: queryURL,
                updateURL: update ? updateURL : nil,
                defaultHeaders: headers,
                requestTimeout: 12
            ),
            session: session
        )
    }

    @Test("GET puts the rendered query and dataset in the URL")
    func getQueryRequest() async throws {
        let session = MockSession(body: #"{"head":{"vars":["s"]},"results":{"bindings":[]}}"#)
        _ = try await client(session, headers: ["X-Client": "SPARQLKit"]).executeSelect(
            select,
            method: .get,
            options: SPARQLQueryRequestOptions(
                defaultGraphs: ["https://example.org/graphs/default"],
                namedGraphs: ["https://example.org/graphs/n1", "https://example.org/graphs/n2"]
            )
        )

        let request = try #require(session.lastRequest)
        let url = try #require(request.url?.absoluteString)
        #expect(url.hasPrefix("https://example.org/sparql?query=SELECT%20%3Fs"))
        #expect(url.contains("default-graph-uri=https%3A%2F%2Fexample.org%2Fgraphs%2Fdefault"))
        #expect(url.contains("named-graph-uri=https%3A%2F%2Fexample.org%2Fgraphs%2Fn1&named-graph-uri=https%3A%2F%2Fexample.org%2Fgraphs%2Fn2"))
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == SPARQLAccept.jsonResults.rawValue)
        #expect(request.value(forHTTPHeaderField: "X-Client") == "SPARQLKit")
        #expect(request.timeoutInterval == 12)
    }

    @Test("GET percent-encodes '+' in paths and arithmetic, so it is not read back as a space", .tags(.security))
    func getEncodesPlus() async throws {
        let session = MockSession(body: #"{"head":{"vars":["o"]},"results":{"bindings":[]}}"#)
        let query = SPARQLSelectQuery(["o"], where: [
            .triple(SPARQLTriplePattern(.variable("s"), .path(.oneOrMore(.property(Foaf.knows.sparql))), .variable("o"))),
            .bind(.binary(.variable("n"), .add, .literal(try Literal("1", datatype: XSD.integer.metadata.id))), as: "m")
        ])
        _ = try await client(session).executeSelect(query, method: .get, options: SPARQLQueryRequestOptions(
            defaultGraphs: ["https://example.org/graphs/a+b"]
        ))

        let request = try #require(session.lastRequest)
        let url = try #require(request.url)
        let encodedQuery = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery)
        #expect(!encodedQuery.contains("+"))
        #expect(encodedQuery.contains("%2B"))
        // Form decoding, as an endpoint reads the query string: '+' is a
        // space, and percent escapes are bytes.
        let parameters = encodedQuery.split(separator: "&").map { pair in
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            return (parts[0], parts[1].replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? "")
        }
        #expect(parameters.first { $0.0 == "query" }?.1 == query.render())
        #expect(parameters.first { $0.0 == "default-graph-uri" }?.1 == "https://example.org/graphs/a+b")
    }

    @Test("POST form-encodes the rendered query and dataset")
    func postQueryRequest() async throws {
        let session = MockSession(body: #"{"head":{"vars":["s"]},"results":{"bindings":[]}}"#)
        _ = try await client(session).executeSelect(
            select,
            options: SPARQLQueryRequestOptions(defaultGraphs: ["https://example.org/g?x=1&y=2"], namedGraphs: ["https://example.org/named#frag"])
        )

        let request = try #require(session.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded; charset=utf-8")
        #expect(request.bodyText.hasPrefix("query=SELECT%20%3Fs%0AWHERE%20%7B"))
        #expect(request.bodyText.contains("default-graph-uri=https%3A%2F%2Fexample.org%2Fg%3Fx%3D1%26y%3D2"))
        #expect(request.bodyText.contains("named-graph-uri=https%3A%2F%2Fexample.org%2Fnamed%23frag"))
    }

    @Test("Literal content that looks like form syntax stays inside the query parameter")
    func formEncodingContainsLiterals() async throws {
        let session = MockSession(body: #"{"head":{"vars":["s"]},"results":{"bindings":[]}}"#)
        let query = SPARQLSelectQuery(["s"], where: [
            .triple(SPARQLTriplePattern(.variable("s"), .variable("p"), .literal(Literal("a&b=1"))))
        ])
        _ = try await client(session).executeSelect(query)
        #expect(try #require(session.lastRequest).bodyText.contains("%22a%26b%3D1%22"))
    }

    @Test("An update goes to the update endpoint with its dataset")
    func updateRequest() async throws {
        let session = MockSession()
        _ = try await client(session).executeUpdate(
            try SPARQLUpdateRequest([insertData]),
            options: SPARQLUpdateRequestOptions(usingGraphs: ["https://example.org/u-default"], usingNamedGraphs: ["https://example.org/u-named"])
        )

        let request = try #require(session.lastRequest)
        #expect(request.url == updateURL)
        #expect(request.httpMethod == "POST")
        #expect(request.bodyText.hasPrefix("update=INSERT%20DATA%20%7B"))
        #expect(request.bodyText.contains("using-graph-uri=https%3A%2F%2Fexample.org%2Fu-default"))
        #expect(request.bodyText.contains("using-named-graph-uri=https%3A%2F%2Fexample.org%2Fu-named"))
    }

    @Test("Without an update endpoint, updates go to the query endpoint")
    func updateFallsBackToQueryEndpoint() async throws {
        let session = MockSession()
        _ = try await client(session, update: false).executeUpdate(try SPARQLUpdateRequest([insertData]))
        #expect(session.lastRequest?.url == queryURL)
    }

    @Test("A batch sent atomically is one request with every operation")
    func atomicBatch() async throws {
        let session = MockSession()
        let batch = try SPARQLUpdateRequest([insertData] + [.drop(.default)])
        let responses = try await client(session).executeUpdateBatch(batch)

        #expect(responses.count == 1)
        #expect(session.requests.count == 1)
        #expect(try #require(session.lastRequest).bodyText.contains("%20%3B%0ADROP%20DEFAULT"))
    }

    @Test("A sequential batch sends one request per operation, in order")
    func sequentialBatch() async throws {
        let session = MockSession(responses: [(200, "first"), (200, "second")])
        let batch = try SPARQLUpdateRequest([insertData] + [.drop(.default)])
        let responses = try await client(session).executeUpdateBatch(batch, mode: .sequentialRequests)

        #expect(responses.map { String(data: $0, encoding: .utf8) } == ["first", "second"])
        #expect(session.requests.count == 2)
        #expect(session.requests[0].bodyText.hasPrefix("update=INSERT%20DATA"))
        #expect(!session.requests[0].bodyText.contains("DROP"))
        #expect(session.requests[1].bodyText == "update=DROP%20DEFAULT")
    }

    @Test("A sequential batch stops at the first failure")
    func sequentialBatchStops() async throws {
        let session = MockSession(responses: [(200, "ok"), (500, "boom"), (200, "never")])
        let batch = try SPARQLUpdateRequest([insertData] + [.drop(.default), .clear(.all)])
        await #expect(throws: SPARQLError.httpStatus(500, body: "boom")) {
            _ = try await client(session).executeUpdateBatch(batch, mode: .sequentialRequests)
        }
        #expect(session.requests.count == 2)
    }

    @Test("An update with no operations is refused")
    func emptyUpdateRefused() async {
        await #expect(throws: SPARQLError.invalidRequest("SPARQL update request must contain at least one operation.")) {
            _ = try await client().executeUpdateBatch(try SPARQLUpdateRequest([]))
        }
    }

    @Test("Header values with control characters are refused")
    func refusesControlCharacters() async {
        await #expect(throws: SPARQLError.invalidRequest("HTTP header names/values must not contain control characters.")) {
            _ = try await client(headers: ["X-Bad": "a\nb"]).executeQuery(select)
        }
    }

    @Test("HTTP failures reach the caller", arguments: [400, 401, 404, 500, 503])
    func httpFailures(code: Int) async {
        await #expect(throws: SPARQLError.httpStatus(code, body: "error-\(code)")) {
            _ = try await client(MockSession(statusCode: code, body: "error-\(code)")).executeQuery(select)
        }
    }

    @Test("ASK decodes its boolean")
    func askDecodes() async throws {
        let ask = SPARQLAskQuery(where: select.patterns)
        #expect(try await client(MockSession(body: #"{"boolean":true}"#)).executeAsk(ask))
    }

    @Test("SELECT decodes its bindings")
    func selectDecodes() async throws {
        let session = MockSession(body: #"{"head":{"vars":["s"]},"results":{"bindings":[{"s":{"type":"uri","value":"http://example.org/s"}}]}}"#)
        let result = try await client(session).executeSelect(select)
        #expect(result.bindings == [["s": iri("http://example.org/s")]])
    }

    @Test("CONSTRUCT and DESCRIBE ask for a graph and decode it", arguments: [SPARQLGraphAccept.turtle, .ntriples])
    func graphQueriesDecode(accept: SPARQLGraphAccept) async throws {
        let session = MockSession(body: "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n")
        let construct = try SPARQLConstructQuery(
            [SPARQLTriplePattern(.variable("s"), .variable("p"), .variable("o"))],
            where: select.patterns
        )
        let constructed = try await client(session).executeGraphQuery(construct, accept: accept)
        #expect(constructed.count == 1)
        #expect(session.lastRequest?.value(forHTTPHeaderField: "Accept") == accept.rawValue)

        let described = try await client(session).executeGraphQuery(try SPARQLDescribeQuery([.iri("http://example.org/s")]), accept: accept)
        #expect(described == constructed)
        #expect(try #require(session.lastRequest).bodyText == "query=DESCRIBE%20%3Chttp%3A%2F%2Fexample.org%2Fs%3E")
    }

    @Test("Relative IRIs in a returned graph resolve against the request URL")
    func graphQueryResolvesRelativeIRIs() async throws {
        let session = MockSession(body: "<#a> <#b> <c> .")
        let construct = try SPARQLConstructQuery(
            [SPARQLTriplePattern(.variable("s"), .variable("p"), .variable("o"))],
            where: select.patterns
        )
        let graph = try await client(session).executeGraphQuery(construct)
        #expect(graph == [Graph.Element(
            subject: .iri("https://example.org/sparql#a"),
            predicate: "https://example.org/sparql#b",
            object: .iri("https://example.org/c")
        )])
    }

    @Test("A result IRI decodes into the declared individual it names", .tags(.decoding))
    func resultIRIsDecodeIntoIndividuals() async throws {
        let session = MockSession(body: #"{"head":{"vars":["f","t"]},"results":{"bindings":[{"f":{"type":"uri","value":"http://www.w3.org/ns/formats/Turtle"},"t":{"type":"uri","value":"http://xmlns.com/foaf/0.1/Person"}}]}}"#)
        let result = try await client(session).executeSelect(select)
        let binding = try #require(result.bindings.first)
        let formats: [any Formats.Format] = [Formats.N_Triples, Formats.Turtle]
        #expect(binding.individual("f", among: formats) === Formats.Turtle)
        #expect(binding.individual("t", among: formats) == nil)
        #expect(binding.individual("unbound", among: formats) == nil)
        #expect(binding.binds("t", to: Foaf.PersonIndividual.sparql))
        #expect(!binding.binds("t", to: Foaf.knows.sparql))
    }
}
