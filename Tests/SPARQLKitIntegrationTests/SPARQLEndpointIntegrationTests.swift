import Foundation
import Testing
@testable import SPARQLKit

@Test
func endpointQueryRoundTripWhenConfigured() async throws {
    guard let endpoint = ProcessInfo.processInfo.environment["SPARQL_ENDPOINT_URL"],
          let endpointURL = URL(string: endpoint)
    else {
        return
    }

    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: endpointURL)
    )

    let query = SPARQLSelectQuery(
        variables: [Variable(rawValue: "s")],
        wherePatterns: ["?s ?p ?o ."],
        limit: 1
    )

    let data = try await client.executeQuery(query, accept: .jsonResults)
    let decoded = try SPARQLJSONResultDecoder().decode(data)

    #expect(decoded.variables.contains(Variable(rawValue: "s")))
}

@Test
func endpointQueryPrintResponsesWhenConfigured() async throws {
    guard let endpoint = ProcessInfo.processInfo.environment["SPARQL_ENDPOINT_URL"],
          let endpointURL = URL(string: endpoint)
    else {
        return
    }

    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: endpointURL)
    )

    let query = SPARQLSelectQuery(
        variables: [Variable(rawValue: "s"), Variable(rawValue: "p"), Variable(rawValue: "o")],
        wherePatterns: ["?s ?p ?o ."],
        limit: 5
    )

    let data = try await client.executeQuery(query, accept: .jsonResults)
    let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
    print("SPARQL endpoint:", endpoint)
    print("SPARQL query:", query.render())
    print("Raw JSON response:")
    print(raw)

    let decoded = try SPARQLJSONResultDecoder().decode(data)
    print("Decoded variables:", decoded.variables.map(\.rawValue).joined(separator: ", "))
    print("Decoded binding count:", decoded.bindings.count)
    for (index, binding) in decoded.bindings.enumerated() {
        let parts = binding.map { key, value in
            "\(key.rawValue)=\(value)"
        }.sorted()
        print("Binding \(index + 1):", parts.joined(separator: ", "))
    }

    #expect(decoded.variables.contains(Variable(rawValue: "s")))
}
