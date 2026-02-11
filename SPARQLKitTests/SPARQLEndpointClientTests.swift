import Foundation
import Testing
@testable import SPARQLKit

@Test
func makeGetQueryRequestEncodesQueryInURL() throws {
    let config = SPARQLEndpointConfiguration(
        queryURL: URL(string: "https://example.org/sparql")!,
        defaultHeaders: ["X-Client": "SPARQLKit"]
    )

    let client = SPARQLEndpointClient(configuration: config)
    let request = try client.makeQueryRequest(
        "SELECT ?s WHERE { ?s ?p ?o . }",
        accept: .jsonResults,
        method: .get
    )

    let absolute = try #require(request.url?.absoluteString)
    #expect(absolute.contains("query=SELECT"))
    #expect(request.httpMethod == "GET")
    #expect(request.value(forHTTPHeaderField: "Accept") == SPARQLAccept.jsonResults.rawValue)
    #expect(request.value(forHTTPHeaderField: "X-Client") == "SPARQLKit")
}

@Test
func makeGetQueryRequestIncludesDatasetParameters() throws {
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!)
    )

    let request = try client.makeQueryRequest(
        "SELECT ?s WHERE { ?s ?p ?o . }",
        accept: .jsonResults,
        method: .get,
        options: SPARQLQueryRequestOptions(
            defaultGraphURIs: ["https://example.org/graphs/default"],
            namedGraphURIs: ["https://example.org/graphs/n1", "https://example.org/graphs/n2"]
        )
    )

    let absolute = try #require(request.url?.absoluteString)
    #expect(absolute.contains("default-graph-uri=https://example.org/graphs/default"))
    #expect(absolute.contains("named-graph-uri=https://example.org/graphs/n1"))
    #expect(absolute.contains("named-graph-uri=https://example.org/graphs/n2"))
}

@Test
func queryRequestUsesConfiguredTimeout() throws {
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(
            queryURL: URL(string: "https://example.org/sparql")!,
            requestTimeout: 12
        )
    )

    let request = try client.makeQueryRequest(
        "SELECT ?s WHERE { ?s ?p ?o . }",
        accept: .jsonResults,
        method: .post
    )

    #expect(request.timeoutInterval == 12)
}

@Test
func makePostQueryRequestIncludesDatasetParameters() throws {
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!)
    )

    let request = try client.makeQueryRequest(
        "SELECT ?s WHERE { ?s ?p ?o . }",
        accept: .jsonResults,
        method: .post,
        options: SPARQLQueryRequestOptions(
            defaultGraphURIs: ["https://example.org/graphs/default"],
            namedGraphURIs: ["https://example.org/graphs/n1"]
        )
    )

    let body = String(data: try #require(request.httpBody), encoding: .utf8) ?? ""
    #expect(body.contains("query=SELECT"))
    #expect(body.contains("default-graph-uri=https%3A%2F%2Fexample.org%2Fgraphs%2Fdefault"))
    #expect(body.contains("named-graph-uri=https%3A%2F%2Fexample.org%2Fgraphs%2Fn1"))
}

@Test
func makePostQueryRequestPercentEncodesPotentialParameterInjectionContent() throws {
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!)
    )

    let request = try client.makeQueryRequest(
        "SELECT * WHERE { ?s ?p \"a&b=1\" . FILTER(CONTAINS(STR(?s), \"x=y\")) }",
        accept: .jsonResults,
        method: .post,
        options: SPARQLQueryRequestOptions(
            defaultGraphURIs: ["https://example.org/g?x=1&y=2"],
            namedGraphURIs: ["https://example.org/named#frag&v=1"]
        )
    )

    let body = String(data: try #require(request.httpBody), encoding: .utf8) ?? ""
    #expect(body.contains("query=SELECT%20%2A%20WHERE"))
    #expect(body.contains("%22a%26b%3D1%22"))
    #expect(body.contains("%22x%3Dy%22"))
    #expect(body.contains("default-graph-uri=https%3A%2F%2Fexample.org%2Fg%3Fx%3D1%26y%3D2"))
    #expect(body.contains("named-graph-uri=https%3A%2F%2Fexample.org%2Fnamed%23frag%26v%3D1"))
}

@Test
func executeUpdateIncludesUsingDatasetParameters() async throws {
    let updateURL = URL(string: "https://example.org/update")!
    let session = MockSession(statusCode: 200, body: "")
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(
            queryURL: URL(string: "https://example.org/sparql")!,
            updateURL: updateURL
        ),
        session: session
    )

    _ = try await client.executeUpdate(
        "INSERT DATA { <s> <p> <o> . }",
        options: SPARQLUpdateRequestOptions(
            usingGraphURIs: ["https://example.org/u-default"],
            usingNamedGraphURIs: ["https://example.org/u-named"]
        )
    )

    let request = try #require(session.lastRequest)
    let body = String(data: try #require(request.httpBody), encoding: .utf8) ?? ""
    #expect(body.contains("update=INSERT%20DATA"))
    #expect(body.contains("using-graph-uri=https%3A%2F%2Fexample.org%2Fu-default"))
    #expect(body.contains("using-named-graph-uri=https%3A%2F%2Fexample.org%2Fu-named"))
}

@Test
func makeUpdateRequestPercentEncodesPotentialParameterInjectionContent() throws {
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(
            queryURL: URL(string: "https://example.org/sparql")!,
            updateURL: URL(string: "https://example.org/update")!
        )
    )

    let request = try client.makeUpdateRequest(
        "INSERT DATA { <s> <p> \"x&y=1\" . }",
        options: SPARQLUpdateRequestOptions(
            usingGraphURIs: ["https://example.org/u?x=1&y=2"],
            usingNamedGraphURIs: ["https://example.org/unamed?a=b&c=d"]
        )
    )

    let body = String(data: try #require(request.httpBody), encoding: .utf8) ?? ""
    #expect(body.contains("update=INSERT%20DATA%20%7B"))
    #expect(body.contains("%22x%26y%3D1%22"))
    #expect(body.contains("using-graph-uri=https%3A%2F%2Fexample.org%2Fu%3Fx%3D1%26y%3D2"))
    #expect(body.contains("using-named-graph-uri=https%3A%2F%2Fexample.org%2Funamed%3Fa%3Db%26c%3Dd"))
}

@Test
func queryRequestOptionsCanBeConstructedFromDatasetAbstraction() throws {
    let dataset = SPARQLDataset(
        defaultGraphs: [try IRI("https://example.org/graphs/default")],
        namedGraphs: [try IRI("https://example.org/graphs/named")]
    )

    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!)
    )

    let request = try client.makeQueryRequest(
        "SELECT ?s WHERE { ?s ?p ?o . }",
        accept: .jsonResults,
        method: .post,
        options: SPARQLQueryRequestOptions(dataset: dataset)
    )

    let body = String(data: try #require(request.httpBody), encoding: .utf8) ?? ""
    #expect(body.contains("default-graph-uri=https%3A%2F%2Fexample.org%2Fgraphs%2Fdefault"))
    #expect(body.contains("named-graph-uri=https%3A%2F%2Fexample.org%2Fgraphs%2Fnamed"))
}

@Test
func updateRequestOptionsCanBeConstructedFromDatasetAbstraction() async throws {
    let dataset = SPARQLDataset(
        usingGraphs: [try IRI("https://example.org/u-default")],
        usingNamedGraphs: [try IRI("https://example.org/u-named")]
    )
    let session = MockSession(statusCode: 200, body: "")
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(
            queryURL: URL(string: "https://example.org/sparql")!,
            updateURL: URL(string: "https://example.org/update")!
        ),
        session: session
    )

    _ = try await client.executeUpdate(
        "INSERT DATA { <s> <p> <o> . }",
        options: SPARQLUpdateRequestOptions(dataset: dataset)
    )

    let request = try #require(session.lastRequest)
    let body = String(data: try #require(request.httpBody), encoding: .utf8) ?? ""
    #expect(body.contains("using-graph-uri=https%3A%2F%2Fexample.org%2Fu-default"))
    #expect(body.contains("using-named-graph-uri=https%3A%2F%2Fexample.org%2Fu-named"))
}

@Test
func executeSelectSupportsDatasetAbstractionDirectly() async throws {
    let dataset = SPARQLDataset(
        defaultGraphs: [try IRI("https://example.org/graphs/default")],
        namedGraphs: [try IRI("https://example.org/graphs/named")]
    )
    let payload = """
    {"head":{"vars":["s"]},"results":{"bindings":[{"s":{"type":"uri","value":"http://example.org/s"}}]}}
    """
    let session = MockSession(statusCode: 200, body: payload)
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
        session: session
    )
    let query = SPARQLSelectQuery(
        variables: [Variable(rawValue: "s")],
        wherePatterns: ["?s ?p ?o ."]
    )

    let result = try await client.executeSelect(query, dataset: dataset)
    #expect(result.bindings.count == 1)

    let request = try #require(session.lastRequest)
    let body = String(data: try #require(request.httpBody), encoding: .utf8) ?? ""
    #expect(body.contains("default-graph-uri=https%3A%2F%2Fexample.org%2Fgraphs%2Fdefault"))
    #expect(body.contains("named-graph-uri=https%3A%2F%2Fexample.org%2Fgraphs%2Fnamed"))
}

@Test
func executeUpdateSupportsDatasetAbstractionDirectly() async throws {
    let dataset = SPARQLDataset(
        usingGraphs: [try IRI("https://example.org/u-default")],
        usingNamedGraphs: [try IRI("https://example.org/u-named")]
    )
    let session = MockSession(statusCode: 200, body: "")
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(
            queryURL: URL(string: "https://example.org/sparql")!,
            updateURL: URL(string: "https://example.org/update")!
        ),
        session: session
    )

    _ = try await client.executeUpdate(
        SPARQLUpdateRequest(operations: [.insertData(triples: ["<s> <p> <o> ."])]),
        dataset: dataset
    )

    let request = try #require(session.lastRequest)
    let body = String(data: try #require(request.httpBody), encoding: .utf8) ?? ""
    #expect(body.contains("using-graph-uri=https%3A%2F%2Fexample.org%2Fu-default"))
    #expect(body.contains("using-named-graph-uri=https%3A%2F%2Fexample.org%2Fu-named"))
}

@Test
func updateRequestFallsBackToQueryEndpointWhenUpdateEndpointMissing() throws {
    let queryURL = try #require(URL(string: "https://example.org/sparql"))
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: queryURL)
    )

    let request = try client.makeUpdateRequest("INSERT DATA { <s> <p> <o> . }")
    #expect(request.url == queryURL)
    #expect(request.httpMethod == "POST")
}

@Test
func updateRequestPrefersExplicitUpdateEndpointWhenConfigured() throws {
    let queryURL = try #require(URL(string: "https://example.org/sparql"))
    let updateURL = try #require(URL(string: "https://example.org/update"))
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(
            queryURL: queryURL,
            updateURL: updateURL
        )
    )

    let request = try client.makeUpdateRequest("INSERT DATA { <s> <p> <o> . }")
    #expect(request.url == updateURL)
    #expect(request.httpMethod == "POST")
}

@Test
func executeUpdateConvenienceMethodsRenderCoreOperationsInRequestBody() async throws {
    let session = MockSession(statusCode: 200, body: "")
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(
            queryURL: URL(string: "https://example.org/sparql")!,
            updateURL: URL(string: "https://example.org/update")!
        ),
        session: session
    )

    _ = try await client.executeInsertData(triples: ["<s> <p> <o> ."])
    let insertBody = String(data: try #require(session.lastRequest?.httpBody), encoding: .utf8) ?? ""
    #expect(insertBody.contains("update=INSERT%20DATA"))

    _ = try await client.executeDeleteData(triples: ["<s> <p> <o> ."])
    let deleteBody = String(data: try #require(session.lastRequest?.httpBody), encoding: .utf8) ?? ""
    #expect(deleteBody.contains("update=DELETE%20DATA"))

    _ = try await client.executeDeleteInsertWhere(
        delete: ["?s <old> ?o ."],
        insert: ["?s <new> ?o ."],
        wherePatterns: ["?s <old> ?o ."]
    )
    let diwBody = String(data: try #require(session.lastRequest?.httpBody), encoding: .utf8) ?? ""
    #expect(diwBody.contains("DELETE%20%7B"))
    #expect(diwBody.contains("INSERT%20%7B"))
    #expect(diwBody.contains("WHERE%20%7B"))
}

@Test
func executeUpdateConvenienceMethodsRenderGraphManagementOperationsInRequestBody() async throws {
    let session = MockSession(statusCode: 200, body: "")
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(
            queryURL: URL(string: "https://example.org/sparql")!,
            updateURL: URL(string: "https://example.org/update")!
        ),
        session: session
    )

    _ = try await client.executeLoad(source: "http://example.org/source", intoGraph: "http://example.org/g")
    let loadBody = String(data: try #require(session.lastRequest?.httpBody), encoding: .utf8) ?? ""
    #expect(loadBody.contains("update=LOAD%20%3Chttp%3A%2F%2Fexample.org%2Fsource%3E%20INTO%20GRAPH%20%3Chttp%3A%2F%2Fexample.org%2Fg%3E"))

    _ = try await client.executeClear(target: .named("http://example.org/g"), silent: true)
    let clearBody = String(data: try #require(session.lastRequest?.httpBody), encoding: .utf8) ?? ""
    #expect(clearBody.contains("update=CLEAR%20SILENT%20GRAPH%20%3Chttp%3A%2F%2Fexample.org%2Fg%3E"))

    _ = try await client.executeCreate(graph: "http://example.org/new")
    let createBody = String(data: try #require(session.lastRequest?.httpBody), encoding: .utf8) ?? ""
    #expect(createBody.contains("update=CREATE%20GRAPH%20%3Chttp%3A%2F%2Fexample.org%2Fnew%3E"))

    _ = try await client.executeDrop(target: .default)
    let dropBody = String(data: try #require(session.lastRequest?.httpBody), encoding: .utf8) ?? ""
    #expect(dropBody.contains("update=DROP%20DEFAULT"))

    _ = try await client.executeCopy(from: "http://example.org/a", to: "http://example.org/b")
    let copyBody = String(data: try #require(session.lastRequest?.httpBody), encoding: .utf8) ?? ""
    #expect(copyBody.contains("update=COPY%20GRAPH%20%3Chttp%3A%2F%2Fexample.org%2Fa%3E%20TO%20GRAPH%20%3Chttp%3A%2F%2Fexample.org%2Fb%3E"))

    _ = try await client.executeMove(from: "http://example.org/a", to: "http://example.org/b", silent: true)
    let moveBody = String(data: try #require(session.lastRequest?.httpBody), encoding: .utf8) ?? ""
    #expect(moveBody.contains("update=MOVE%20SILENT%20GRAPH%20%3Chttp%3A%2F%2Fexample.org%2Fa%3E%20TO%20GRAPH%20%3Chttp%3A%2F%2Fexample.org%2Fb%3E"))

    _ = try await client.executeAdd(from: "http://example.org/a", to: "http://example.org/b")
    let addBody = String(data: try #require(session.lastRequest?.httpBody), encoding: .utf8) ?? ""
    #expect(addBody.contains("update=ADD%20GRAPH%20%3Chttp%3A%2F%2Fexample.org%2Fa%3E%20TO%20GRAPH%20%3Chttp%3A%2F%2Fexample.org%2Fb%3E"))
}

@Test
func executeUpdateBatchSingleRequestAtomicSendsCombinedUpdate() async throws {
    let session = RecordingMockSession(responses: [(200, "ok")])
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(
            queryURL: URL(string: "https://example.org/sparql")!,
            updateURL: URL(string: "https://example.org/update")!
        ),
        session: session
    )

    let update = SPARQLUpdateRequest(
        operations: [
            .insertData(triples: ["<s1> <p> <o> ."]),
            .deleteData(triples: ["<s2> <p> <o> ."])
        ]
    )

    let responses = try await client.executeUpdateBatch(update, mode: .singleRequestAtomic)
    #expect(responses.count == 1)
    #expect(session.requests.count == 1)

    let body = String(data: try #require(session.requests.first?.httpBody), encoding: .utf8) ?? ""
    #expect(body.contains("update=INSERT%20DATA"))
    #expect(body.contains("%3B%0ADELETE%20DATA"))
}

@Test
func executeUpdateBatchSequentialRequestsSendsEachOperationInOrder() async throws {
    let session = RecordingMockSession(responses: [(200, "first"), (200, "second")])
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(
            queryURL: URL(string: "https://example.org/sparql")!,
            updateURL: URL(string: "https://example.org/update")!
        ),
        session: session
    )

    let update = SPARQLUpdateRequest(
        operations: [
            .insertData(triples: ["<s1> <p> <o> ."]),
            .deleteData(triples: ["<s2> <p> <o> ."])
        ]
    )

    let responses = try await client.executeUpdateBatch(update, mode: .sequentialRequests)
    #expect(responses.count == 2)
    #expect(String(data: responses[0], encoding: .utf8) == "first")
    #expect(String(data: responses[1], encoding: .utf8) == "second")
    #expect(session.requests.count == 2)

    let firstBody = String(data: try #require(session.requests[0].httpBody), encoding: .utf8) ?? ""
    let secondBody = String(data: try #require(session.requests[1].httpBody), encoding: .utf8) ?? ""
    #expect(firstBody.contains("update=INSERT%20DATA"))
    #expect(!firstBody.contains("DELETE%20DATA"))
    #expect(secondBody.contains("update=DELETE%20DATA"))
}

@Test
func executeUpdateBatchSequentialRequestsStopsOnFirstFailure() async throws {
    let session = RecordingMockSession(responses: [(200, "first"), (500, "boom"), (200, "third")])
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(
            queryURL: URL(string: "https://example.org/sparql")!,
            updateURL: URL(string: "https://example.org/update")!
        ),
        session: session
    )

    let update = SPARQLUpdateRequest(
        operations: [
            .insertData(triples: ["<s1> <p> <o> ."]),
            .deleteData(triples: ["<s2> <p> <o> ."]),
            .insertData(triples: ["<s3> <p> <o> ."])
        ]
    )

    await #expect(throws: SPARQLError.httpStatus(500, body: "boom")) {
        _ = try await client.executeUpdateBatch(update, mode: .sequentialRequests)
    }
    #expect(session.requests.count == 2)
}

@Test
func executeUpdateBatchRejectsEmptyOperationList() async throws {
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
        session: MockSession(statusCode: 200, body: "")
    )

    await #expect(throws: SPARQLError.invalidRequest("SPARQL update request must contain at least one operation.")) {
        _ = try await client.executeUpdateBatch(SPARQLUpdateRequest(operations: []))
    }
}

@Test
func queryRequestRejectsInvalidHeaderControlCharacters() throws {
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(
            queryURL: URL(string: "https://example.org/sparql")!,
            defaultHeaders: ["X-Bad\nHeader": "value"]
        )
    )

    #expect(throws: SPARQLError.invalidRequest("HTTP header names/values must not contain control characters.")) {
        _ = try client.makeQueryRequest(
            "SELECT ?s WHERE { ?s ?p ?o . }",
            accept: .jsonResults,
            method: .get
        )
    }
}

@Test
func executeQueryMapsHTTPErrors() async throws {
    let statusCodes = [400, 401, 403, 404, 409, 500]

    for code in statusCodes {
        let session = MockSession(statusCode: code, body: "error-\(code)")
        let client = SPARQLEndpointClient(
            configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
            session: session
        )

        let query = SPARQLSelectQuery(
            variables: [Variable(rawValue: "s")],
            wherePatterns: ["?s ?p ?o ."]
        )

        await #expect(throws: SPARQLError.httpStatus(code, body: "error-\(code)")) {
            _ = try await client.executeQuery(query)
        }
    }
}

@Test
func executeQueryRejectsGraphQueryFormsForResultMediaTypes() async throws {
    let session = MockSession(statusCode: 200, body: "")
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
        session: session
    )

    let query = SPARQLConstructQuery(
        constructPatterns: ["?s ?p ?o ."],
        wherePatterns: ["?s ?p ?o ."]
    )

    await #expect(throws: SPARQLError.invalidRequest("CONSTRUCT/DESCRIBE queries require graph media type accept headers.")) {
        _ = try await client.executeQuery(query, accept: .jsonResults)
    }
}

@Test
func executeGraphQueryRejectsSelectForm() async throws {
    let session = MockSession(statusCode: 200, body: "")
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
        session: session
    )

    let query = SPARQLSelectQuery(
        variables: [Variable(rawValue: "s")],
        wherePatterns: ["?s ?p ?o ."]
    )

    await #expect(throws: SPARQLError.invalidRequest("Graph query execution is only valid for CONSTRUCT or DESCRIBE.")) {
        _ = try await client.executeGraphQuery(query, accept: .turtle)
    }
}

@Test
func executeGraphQuerySetsGraphAcceptHeader() async throws {
    let session = MockSession(statusCode: 200, body: "")
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
        session: session
    )

    let query = SPARQLDescribeQuery(
        variables: [Variable(rawValue: "s")],
        wherePatterns: ["?s ?p ?o ."]
    )

    _ = try await client.executeGraphQuery(query, accept: .turtle)

    let request = try #require(session.lastRequest)
    #expect(request.value(forHTTPHeaderField: "Accept") == SPARQLGraphAccept.turtle.rawValue)
}

@Test
func executeAskDecodesBooleanResult() async throws {
    let session = MockSession(statusCode: 200, body: "{\"boolean\":true}")
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
        session: session
    )
    let query = SPARQLAskQuery(wherePatterns: ["?s ?p ?o ."])

    let value = try await client.executeAsk(query)
    #expect(value)
}

@Test
func executeSelectDecodesBindingsResult() async throws {
    let body = """
    {"head":{"vars":["s"]},"results":{"bindings":[{"s":{"type":"uri","value":"http://example.org/s"}}]}}
    """
    let session = MockSession(statusCode: 200, body: body)
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
        session: session
    )
    let query = SPARQLSelectQuery(
        variables: [Variable(rawValue: "s")],
        wherePatterns: ["?s ?p ?o ."]
    )

    let result = try await client.executeSelect(query)
    #expect(result.bindings.count == 1)
    let first = try #require(result.bindings.first)
    let expected = try RDFTerm.iri("http://example.org/s")
    #expect(first[Variable(rawValue: "s")] == expected)
}

@Test
func executeConstructUsesGraphQueryExecutionPath() async throws {
    let turtle = "<http://example.org/s> <http://example.org/p> <http://example.org/o> ."
    let session = MockSession(statusCode: 200, body: turtle)
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
        session: session
    )
    let query = SPARQLConstructQuery(
        constructPatterns: ["?s ?p ?o ."],
        wherePatterns: ["?s ?p ?o ."]
    )

    let data = try await client.executeConstruct(query, accept: .turtle)
    #expect(String(data: data, encoding: .utf8) == turtle)
}

@Test
func executeDescribeUsesGraphQueryExecutionPath() async throws {
    let turtle = "<http://example.org/s> <http://example.org/p> <http://example.org/o> ."
    let session = MockSession(statusCode: 200, body: turtle)
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
        session: session
    )
    let query = SPARQLDescribeQuery(
        variables: [Variable(rawValue: "s")],
        wherePatterns: ["?s ?p ?o ."]
    )

    let data = try await client.executeDescribe(query, accept: .turtle)
    #expect(String(data: data, encoding: .utf8) == turtle)
}

private final class MockSession: URLSessioning, @unchecked Sendable {
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

private final class RecordingMockSession: URLSessioning, @unchecked Sendable {
    private let responses: [(statusCode: Int, body: String)]
    private var responseIndex = 0
    private(set) var requests: [URLRequest] = []

    init(responses: [(Int, String)]) {
        self.responses = responses.map { (statusCode: $0.0, body: $0.1) }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let response = currentResponse()
        let data = Data(response.body.utf8)
        let http = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, http)
    }

    private func currentResponse() -> (statusCode: Int, body: String) {
        guard !responses.isEmpty else {
            return (200, "")
        }
        if responseIndex >= responses.count {
            return responses[responses.count - 1]
        }

        defer { responseIndex += 1 }
        return responses[responseIndex]
    }
}
