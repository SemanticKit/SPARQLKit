import Testing
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import IRIKit
import RDFCore
@testable import SPARQLKit

@Test
func serviceClauseRendersWithEndpointAndPatterns() {
    let clause = SPARQLServiceClause(
        endpointIRI: "http://dbpedia.org/sparql",
        patterns: [
            "<http://dbpedia.org/resource/Snoopy> <http://xmlns.com/foaf/0.1/name> ?name ."
        ]
    )

    let rendered = clause.render()
    #expect(rendered.contains("SERVICE <http://dbpedia.org/sparql>"))
    #expect(rendered.contains("?name"))
}

@Test
func federatedSelectRendersLocalAndServicePatterns() throws {
    let query = SPARQLFederatedSelectQuery(
        prefixes: ["foaf": try IRI(validating: "http://xmlns.com/foaf/0.1/")],
        variables: [Variable(rawValue: "name")],
        localPatterns: ["?person foaf:knows ?friend ."],
        serviceClauses: [
            SPARQLServiceClause(
                endpointIRI: "http://dbpedia.org/sparql",
                patterns: ["<http://dbpedia.org/resource/Snoopy> foaf:name ?name ."],
                silent: true
            )
        ],
        limit: 1
    )

    let rendered = query.render()

    #expect(rendered.contains("SELECT ?name"))
    #expect(rendered.contains("?person foaf:knows ?friend ."))
    #expect(rendered.contains("SERVICE SILENT <http://dbpedia.org/sparql>"))
    #expect(rendered.contains("LIMIT 1"))
}

@Test
func federatedBindingAnalysisFindsPropagatedVariables() {
    let query = SPARQLFederatedSelectQuery(
        variables: [Variable(rawValue: "person"), Variable(rawValue: "name")],
        localPatterns: [
            "?person <http://xmlns.com/foaf/0.1/knows> ?friend .",
            "?friend <http://xmlns.com/foaf/0.1/name> ?localName ."
        ],
        serviceClauses: [
            SPARQLServiceClause(
                endpointIRI: "http://dbpedia.org/sparql",
                patterns: [
                    "?friend <http://xmlns.com/foaf/0.1/name> ?name .",
                    "?friend <http://xmlns.com/foaf/0.1/page> ?page ."
                ]
            )
        ]
    )

    let analysis = query.bindingAnalysis()

    #expect(analysis.localVariables.contains(Variable(rawValue: "friend")))
    #expect(analysis.serviceVariablesByEndpoint["http://dbpedia.org/sparql"]?.contains(Variable(rawValue: "friend")) == true)
    #expect(analysis.propagatedVariables.contains(Variable(rawValue: "friend")))
    #expect(analysis.serviceOnlyVariables.contains(Variable(rawValue: "page")))
}

@Test
func federatedBindingAnalysisHandlesNoLocalBindings() {
    let query = SPARQLFederatedSelectQuery(
        variables: [Variable(rawValue: "name")],
        localPatterns: [],
        serviceClauses: [
            SPARQLServiceClause(
                endpointIRI: "http://dbpedia.org/sparql",
                patterns: ["?s <http://xmlns.com/foaf/0.1/name> ?name ."]
            )
        ]
    )

    let analysis = query.bindingAnalysis()
    #expect(analysis.propagatedVariables.isEmpty)
    #expect(analysis.serviceOnlyVariables.contains(Variable(rawValue: "s")))
    #expect(analysis.serviceOnlyVariables.contains(Variable(rawValue: "name")))
}

@Test
func federatedSelectExecutionDecodesBindingsPayload() async throws {
    let payload = """
    {"head":{"vars":["s"]},"results":{"bindings":[{"s":{"type":"uri","value":"http://example.org/s"}}]}}
    """
    let session = FederatedExecutionMockSession(result: .success((200, payload)))
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
        session: session
    )

    let query = SPARQLFederatedSelectQuery(
        variables: [Variable(rawValue: "s")],
        serviceClauses: [
            SPARQLServiceClause(
                endpointIRI: "http://dbpedia.org/sparql",
                patterns: ["?s ?p ?o ."]
            )
        ]
    )

    let result = try await client.executeFederatedSelect(query)
    #expect(result.bindings.count == 1)
    let first = try #require(result.bindings.first)
    let expected = try ObjectTerm(iri: "http://example.org/s")
    #expect(first[Variable(rawValue: "s")] == expected)
}

@Test
func federatedSelectExecutionPropagatesTimeoutErrors() async throws {
    let session = FederatedExecutionMockSession(result: .failure(URLError(.timedOut)))
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
        session: session
    )

    let query = SPARQLFederatedSelectQuery(
        variables: [Variable(rawValue: "s")],
        serviceClauses: [
            SPARQLServiceClause(
                endpointIRI: "http://dbpedia.org/sparql",
                patterns: ["?s ?p ?o ."]
            )
        ]
    )

    await #expect(throws: URLError(.timedOut)) {
        _ = try await client.executeFederatedSelect(query)
    }
}

private final class FederatedExecutionMockSession: URLSessioning, @unchecked Sendable {
    private let result: Result<(Int, String), Error>

    init(result: Result<(Int, String), Error>) {
        self.result = result
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        switch result {
        case let .success((statusCode, body)):
            return (
                Data(body.utf8),
                HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            )
        case let .failure(error):
            throw error
        }
    }
}
