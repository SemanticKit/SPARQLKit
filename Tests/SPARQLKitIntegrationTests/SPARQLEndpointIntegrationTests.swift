import EntailmentRegimes
import FOAF
import Formats
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import IRIKit
import RDFCore
import RDFFormats
import ServiceDescription
import Testing
@testable import SPARQLKit

@Suite("Live SPARQL endpoint", .tags(.liveEndpoint))
struct SPARQLEndpointIntegrationTests {

    func anyTriple() -> SPARQLPattern {
        .triple(SPARQLTriplePattern(.variable("s"), .variable("p"), .variable("o")))
    }

    @Test("A SELECT round-trips", .enabled(if: Environment.queryURL != nil))
    func selectRoundTrip() async throws {
        let client = SPARQLEndpointClient(configuration: SPARQLEndpointConfiguration(queryURL: try #require(Environment.queryURL)))
        let result = try await client.executeSelect(SPARQLSelectQuery(["s"], where: [anyTriple()], limit: 1))
        #expect(result.variables.contains("s"))
    }

    @Test("Inserted data can be queried back", .enabled(if: Environment.queryURL != nil && Environment.updateURL != nil))
    func updateRoundTrip() async throws {
        let client = SPARQLEndpointClient(configuration: SPARQLEndpointConfiguration(
            queryURL: try #require(Environment.queryURL),
            updateURL: Environment.updateURL
        ))
        let graph = Environment.iri("SPARQL_TEST_GRAPH_IRI") ?? "http://example.org/test-graph"
        let subject: IRI = "http://example.org/sparqlkit/integration/sequence"
        let objectA: IRI = "http://example.org/oA"
        let objectB: IRI = "http://example.org/oB"
        func triple(_ object: IRI) -> SPARQLTriplePattern {
            SPARQLTriplePattern(.iri(subject), .property(FOAF.knows.sparql), .iri(object))
        }

        _ = try await client.executeUpdate(try SPARQLUpdateRequest([
            .clear(.named(graph), silent: true),
            .insertData([triple(objectA)], graph: graph),
            .deleteData([triple(objectA)], graph: graph),
            .insertData([triple(objectB)], graph: graph)
        ]))

        let result = try await client.executeSelect(SPARQLSelectQuery(["o"], where: [
            .graph(.iri(graph), [.triple(SPARQLTriplePattern(.iri(subject), .property(FOAF.knows.sparql), .variable("o")))])
        ]))
        let values = result.bindings.compactMap { $0["o"] }
        #expect(values.contains(.iri(objectB)))
        #expect(!values.contains(.iri(objectA)))
    }

    @Test("A graph put through the Graph Store comes back", .enabled(if: Environment.graphStoreURL != nil))
    func graphStoreRoundTrip() async throws {
        let client = SPARQLGraphStoreClient(configuration: SPARQLGraphStoreConfiguration(graphStoreURL: try #require(Environment.graphStoreURL)))
        let graph = Environment.iri("SPARQL_TEST_GRAPH_IRI") ?? "http://example.org/sparqlkit/graphstore"
        let triple = Graph.Element(subject: .iri("http://example.org/s"), predicate: IRI(of: FOAF.knows)!, object: .iri("http://example.org/o"))

        _ = try await client.putGraph([triple], graph: .named(graph))
        #expect(try await client.getGraph(.named(graph)).contains(triple))
        #expect((200 ... 299).contains(try await client.headGraph(.named(graph)).statusCode))
        _ = try await client.deleteGraph(.named(graph))
    }

    @Test("A federated query reaches the remote service", .enabled(if: Environment.queryURL != nil && Environment.iri("SPARQL_FEDERATED_ENDPOINT_URL") != nil))
    func federatedRoundTrip() async throws {
        let client = SPARQLEndpointClient(configuration: SPARQLEndpointConfiguration(queryURL: try #require(Environment.queryURL)))
        let remote = try #require(Environment.iri("SPARQL_FEDERATED_ENDPOINT_URL"))
        let subject = Environment.iri("SPARQL_FEDERATED_SUBJECT_IRI")
        let local: SPARQLPattern
        if let subject {
            local = .values(try SPARQLValues(variables: ["s"], rows: [[.iri(subject)]]))
        } else {
            local = anyTriple()
        }
        let query = SPARQLSelectQuery(["s", "p", "o"], where: [local, .service(remote, silent: true, [anyTriple()])], limit: 1)

        #expect(query.federatedBindingAnalysis().propagatedVariables.contains("s"))
        let result = try await client.executeSelect(query)
        #expect(result.variables.contains("s"))
        if Environment.values["SPARQL_FEDERATED_ASSERT_BINDINGS"] == "1" {
            #expect(!result.bindings.isEmpty)
            if let subject {
                #expect(result.bindings.compactMap { $0["s"] }.contains(.iri(subject)))
            }
        }
    }

    @Test("Each configured entailment regime answers", .enabled(if: Environment.queryURL != nil && Environment.iris("SPARQL_TEST_ENTAILMENT_REGIMES").count >= 2))
    func entailmentRegimes() async throws {
        let client = SPARQLEndpointClient(configuration: SPARQLEndpointConfiguration(queryURL: try #require(Environment.queryURL)))
        let declared = EntailmentRegimes.ontology.compactMap { $0 as? any EntailmentRegimes.Entailment }
        let regimes = Environment.iris("SPARQL_TEST_ENTAILMENT_REGIMES").compactMap(declared.individual(denotedBy:))
        try #require(regimes.count >= 2)
        let service = ServiceDescription.ServiceIndividual()
        service.resultFormat = [Formats.SPARQL_Results_JSON]
        let description = SPARQLServiceDescription(service: service, entailmentRegimes: regimes)
        let ask = SPARQLAskQuery(where: [anyTriple()])

        var answers: [Data] = []
        for regime in regimes.prefix(2) {
            answers.append(try await client.executeQuery(
                ask,
                options: SPARQLQueryRequestOptions(requiredEntailmentRegime: regime),
                serviceDescription: description
            ))
        }
        for answer in answers {
            guard case .boolean = try (SPARQLJSONResultDecoder().decode(answer) as SPARQLQueryResult) else {
                Issue.record("An ASK answered without a boolean.")
                continue
            }
        }
        if Environment.values["SPARQL_EXPECT_ENTAILMENT_DIFFERENCE"] == "1" {
            #expect(answers[0] != answers[1])
        }
    }

    @Test("Two endpoints answer the same ASK", .enabled(if: Environment.url("SPARQL_ENTAILMENT_ENDPOINT_A_URL") != nil && Environment.url("SPARQL_ENTAILMENT_ENDPOINT_B_URL") != nil))
    func crossEndpointEntailment() async throws {
        let ask = SPARQLAskQuery(where: [anyTriple()])
        var answers: [Data] = []
        for name in ["SPARQL_ENTAILMENT_ENDPOINT_A_URL", "SPARQL_ENTAILMENT_ENDPOINT_B_URL"] {
            let client = SPARQLEndpointClient(configuration: SPARQLEndpointConfiguration(queryURL: try #require(Environment.url(name))))
            answers.append(try await client.executeQuery(ask))
        }
        for answer in answers {
            guard case .boolean = try (SPARQLJSONResultDecoder().decode(answer) as SPARQLQueryResult) else {
                Issue.record("An ASK answered without a boolean.")
                continue
            }
        }
        if Environment.values["SPARQL_EXPECT_CROSS_ENDPOINT_ENTAILMENT_DIFFERENCE"] == "1" {
            #expect(answers[0] != answers[1])
        }
    }
}
