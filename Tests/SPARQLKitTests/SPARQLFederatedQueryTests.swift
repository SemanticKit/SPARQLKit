import FOAF
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import IRIKit
import Testing
@testable import SPARQLKit

@Suite("Federated queries", .tags(.rendering))
struct SPARQLFederatedQueryTests {
    let dbpedia: IRI = "http://dbpedia.org/sparql"
    let knows = FOAF.knows.sparql
    let foafName = FOAF.name.sparql
    let page = FOAF.page.sparql

    func pattern(_ s: Variable, _ p: SPARQLTerm, _ o: Variable) -> SPARQLPattern {
        .triple(SPARQLTriplePattern(.variable(s), .property(p), .variable(o)))
    }

    @Test("SERVICE renders its endpoint, SILENT and pattern")
    func serviceRenders() {
        let query = SPARQLSelectQuery(
            ["name"],
            where: [
                pattern("person", knows, "friend"),
                .service(dbpedia, silent: true, [pattern("friend", foafName, "name")])
            ],
            limit: 1
        )

        #expect(query.render() == """
            SELECT ?name
            WHERE {
              ?person <http://xmlns.com/foaf/0.1/knows> ?friend .
              SERVICE SILENT <http://dbpedia.org/sparql> {
                ?friend <http://xmlns.com/foaf/0.1/name> ?name .
              }
            }
            LIMIT 1
            """)
    }

    @Test("Binding analysis separates local, shared and service-only variables")
    func bindingAnalysisFindsSharedVariables() {
        let query = SPARQLSelectQuery(where: [
            pattern("person", knows, "friend"),
            .service(dbpedia, silent: false, [pattern("friend", foafName, "name"), pattern("friend", page, "page")])
        ])

        let analysis = query.federatedBindingAnalysis()
        #expect(analysis.localVariables == ["person", "friend"])
        #expect(analysis.services == [.init(endpoint: dbpedia, variables: ["friend", "name", "page"])])
        #expect(analysis.propagatedVariables == ["friend"])
        #expect(analysis.serviceOnlyVariables == ["name", "page"])
    }

    @Test("A query with no local pattern shares nothing")
    func bindingAnalysisWithoutLocalPatterns() {
        let query = SPARQLSelectQuery(where: [.service(dbpedia, silent: false, [pattern("s", foafName, "name")])])

        let analysis = query.federatedBindingAnalysis()
        #expect(analysis.propagatedVariables.isEmpty)
        #expect(analysis.serviceOnlyVariables == ["s", "name"])
    }

    @Test("A federated SELECT runs like any SELECT and decodes its bindings", .tags(.protocol))
    func federatedSelectExecutes() async throws {
        let session = MockSession(body: #"{"head":{"vars":["s"]},"results":{"bindings":[{"s":{"type":"uri","value":"http://example.org/s"}}]}}"#)
        let client = SPARQLEndpointClient(
            configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
            session: session
        )
        let query = SPARQLSelectQuery(["s"], where: [.service(dbpedia, silent: false, [pattern("s", foafName, "name")])])

        let result = try await client.executeSelect(query)
        #expect(result.bindings == [["s": iri("http://example.org/s")]])
        #expect(try #require(session.lastRequest).bodyText.contains("SERVICE%20%3Chttp%3A%2F%2Fdbpedia.org%2Fsparql%3E"))
    }

    @Test("A transport failure reaches the caller", .tags(.protocol))
    func transportFailurePropagates() async throws {
        let client = SPARQLEndpointClient(
            configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
            session: MockSession(failingWith: URLError(.timedOut))
        )
        let query = SPARQLSelectQuery(["s"], where: [.service(dbpedia, silent: false, [pattern("s", foafName, "name")])])

        await #expect(throws: URLError(.timedOut)) {
            _ = try await client.executeSelect(query)
        }
    }
}
