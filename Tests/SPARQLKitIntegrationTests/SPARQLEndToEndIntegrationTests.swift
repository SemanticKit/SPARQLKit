import Foundation
import Testing
@testable import SPARQLKit

@Test
func updateRoundTripWhenConfigured() async throws {
    let env = ProcessInfo.processInfo.environment
    guard let queryEndpoint = env["SPARQL_ENDPOINT_URL"],
          let updateEndpoint = env["SPARQL_UPDATE_ENDPOINT_URL"],
          let queryURL = URL(string: queryEndpoint),
          let updateURL = URL(string: updateEndpoint)
    else {
        return
    }

    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(
            queryURL: queryURL,
            updateURL: updateURL
        )
    )

    let graphIRI = env["SPARQL_TEST_GRAPH_IRI"] ?? "http://example.org/test-graph"
    let subject = "http://example.org/sparqlkit/integration/subject"

    let update = SPARQLUpdateRequest(
        operations: [
            .clear(target: .named(graphIRI), silent: true),
            .insertData(triples: ["GRAPH <\(graphIRI)> { <\(subject)> <http://example.org/p> <http://example.org/o> . }"])
        ]
    )

    _ = try await client.executeUpdate(update)

    let query = SPARQLSelectQuery(
        variables: [Variable(rawValue: "s")],
        wherePatterns: ["GRAPH <\(graphIRI)> { ?s <http://example.org/p> <http://example.org/o> . }"],
        limit: 1
    )

    let data = try await client.executeQuery(query, accept: .jsonResults)
    let result = try SPARQLJSONResultDecoder().decode(data)
    #expect(!result.bindings.isEmpty)
}

@Test
func multiOperationUpdateSequenceWhenConfigured() async throws {
    let env = ProcessInfo.processInfo.environment
    guard let queryEndpoint = env["SPARQL_ENDPOINT_URL"],
          let updateEndpoint = env["SPARQL_UPDATE_ENDPOINT_URL"],
          let queryURL = URL(string: queryEndpoint),
          let updateURL = URL(string: updateEndpoint)
    else {
        return
    }

    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(
            queryURL: queryURL,
            updateURL: updateURL
        )
    )

    let graphIRI = env["SPARQL_TEST_GRAPH_IRI"] ?? "http://example.org/test-graph"
    let subject = "http://example.org/sparqlkit/integration/sequence"
    let predicate = "http://example.org/p"
    let objectA = "http://example.org/oA"
    let objectB = "http://example.org/oB"

    let update = SPARQLUpdateRequest(
        operations: [
            .clear(target: .named(graphIRI), silent: true),
            .insertData(triples: ["GRAPH <\(graphIRI)> { <\(subject)> <\(predicate)> <\(objectA)> . }"]),
            .deleteData(triples: ["GRAPH <\(graphIRI)> { <\(subject)> <\(predicate)> <\(objectA)> . }"]),
            .insertData(triples: ["GRAPH <\(graphIRI)> { <\(subject)> <\(predicate)> <\(objectB)> . }"])
        ]
    )

    _ = try await client.executeUpdate(update)

    let query = SPARQLSelectQuery(
        variables: [Variable(rawValue: "o")],
        wherePatterns: ["GRAPH <\(graphIRI)> { <\(subject)> <\(predicate)> ?o . }"]
    )

    let data = try await client.executeQuery(query, accept: .jsonResults)
    let result = try SPARQLJSONResultDecoder().decode(data)

    let values = result.bindings.compactMap { $0[Variable(rawValue: "o")] }
    let expectedFinal = try RDFTerm.iri(objectB)
    let unexpectedPrior = try RDFTerm.iri(objectA)

    #expect(values.contains(expectedFinal))
    #expect(!values.contains(unexpectedPrior))
}

@Test
func graphStoreRoundTripWhenConfigured() async throws {
    let env = ProcessInfo.processInfo.environment
    guard let graphStoreEndpoint = env["SPARQL_GRAPH_STORE_URL"],
          let graphStoreURL = URL(string: graphStoreEndpoint)
    else {
        return
    }

    let graphIRI = env["SPARQL_TEST_GRAPH_IRI"] ?? "http://example.org/sparqlkit/graphstore"

    let client = SPARQLGraphStoreClient(
        configuration: SPARQLGraphStoreConfiguration(graphStoreURL: graphStoreURL)
    )

    let turtle = Data("<http://example.org/s> <http://example.org/p> <http://example.org/o> .".utf8)

    _ = try await client.putGraph(
        turtle,
        contentType: SPARQLGraphAccept.turtle.rawValue,
        graph: .named(graphIRI)
    )

    let fetched = try await client.getGraph(graph: .named(graphIRI), accept: .turtle)
    let fetchedString = String(data: fetched, encoding: .utf8) ?? ""
    #expect(fetchedString.contains("http://example.org/s"))

    _ = try await client.deleteGraph(graph: .named(graphIRI))
}

@Test
func graphStoreHeadRoundTripWhenConfigured() async throws {
    let env = ProcessInfo.processInfo.environment
    guard let graphStoreEndpoint = env["SPARQL_GRAPH_STORE_URL"],
          let graphStoreURL = URL(string: graphStoreEndpoint)
    else {
        return
    }

    let graphIRI = env["SPARQL_TEST_GRAPH_IRI"] ?? "http://example.org/sparqlkit/graphstore-head"

    let client = SPARQLGraphStoreClient(
        configuration: SPARQLGraphStoreConfiguration(graphStoreURL: graphStoreURL)
    )

    let turtle = Data("<http://example.org/head-s> <http://example.org/p> <http://example.org/o> .".utf8)
    _ = try await client.putGraph(
        turtle,
        contentType: SPARQLGraphAccept.turtle.rawValue,
        graph: .named(graphIRI)
    )

    let response = try await client.headGraph(graph: .named(graphIRI))
    #expect((200 ... 299).contains(response.statusCode))

    _ = try await client.deleteGraph(graph: .named(graphIRI))
}

@Test
func federatedQueryRoundTripWhenConfigured() async throws {
    let env = ProcessInfo.processInfo.environment
    guard let endpoint = env["SPARQL_ENDPOINT_URL"],
          let endpointURL = URL(string: endpoint),
          let remote = env["SPARQL_FEDERATED_ENDPOINT_URL"]
    else {
        return
    }

    let strictAssertions = env["SPARQL_FEDERATED_ASSERT_BINDINGS"] == "1"
    let propagatedSubjectIRI = env["SPARQL_FEDERATED_SUBJECT_IRI"]

    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: endpointURL)
    )

    let localPatterns: [String]
    if let propagatedSubjectIRI {
        localPatterns = ["VALUES ?s { <\(propagatedSubjectIRI)> }"]
    } else {
        localPatterns = ["?s ?p ?o ."]
    }

    let federated = SPARQLFederatedSelectQuery(
        variables: [Variable(rawValue: "s"), Variable(rawValue: "p"), Variable(rawValue: "o")],
        localPatterns: localPatterns,
        serviceClauses: [
            SPARQLServiceClause(
                endpointIRI: remote,
                patterns: ["?s ?p ?o ."],
                silent: true
            )
        ],
        limit: 1
    )

    let analysis = federated.bindingAnalysis()
    #expect(analysis.propagatedVariables.contains(Variable(rawValue: "s")))

    let data = try await client.executeQuery(federated, accept: .jsonResults)
    let result = try SPARQLJSONResultDecoder().decode(data)
    #expect(result.variables.contains(Variable(rawValue: "s")))

    if strictAssertions {
        #expect(!result.bindings.isEmpty)
        #expect(result.bindings.allSatisfy { $0[Variable(rawValue: "s")] != nil })
    }

    if strictAssertions, let propagatedSubjectIRI {
        let expected = try RDFTerm.iri(propagatedSubjectIRI)
        let values = result.bindings.compactMap { $0[Variable(rawValue: "s")] }
        #expect(values.contains(expected))
    }
}
