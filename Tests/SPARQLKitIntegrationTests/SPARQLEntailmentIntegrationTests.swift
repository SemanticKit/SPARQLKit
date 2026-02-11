import Foundation
import Testing
@testable import SPARQLKit

@Test
func entailmentRoundTripAcrossConfiguredRegimesWhenAvailable() async throws {
    let env = ProcessInfo.processInfo.environment
    guard let endpoint = env["SPARQL_ENDPOINT_URL"],
          let endpointURL = URL(string: endpoint),
          let regimesCSV = env["SPARQL_TEST_ENTAILMENT_REGIMES"]
    else {
        return
    }

    let regimes = regimesCSV
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    guard regimes.count >= 2 else {
        return
    }

    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: endpointURL)
    )

    let query = SPARQLAskQuery(wherePatterns: ["?s ?p ?o ."])
    let capabilities = SPARQLServiceDescription(
        resultFormats: [SPARQLAccept.jsonResults.rawValue],
        entailmentRegimes: Set(regimes)
    )

    let firstData = try await client.executeQuery(
        query,
        accept: .jsonResults,
        options: SPARQLQueryRequestOptions(requiredEntailmentRegime: regimes[0]),
        serviceDescription: capabilities
    )
    let secondData = try await client.executeQuery(
        query,
        accept: .jsonResults,
        options: SPARQLQueryRequestOptions(requiredEntailmentRegime: regimes[1]),
        serviceDescription: capabilities
    )

    let decoder = SPARQLJSONResultDecoder()
    let firstResult = try decoder.decodeQueryResult(firstData)
    let secondResult = try decoder.decodeQueryResult(secondData)
    #expect(firstResult == .boolean(true) || firstResult == .boolean(false))
    #expect(secondResult == .boolean(true) || secondResult == .boolean(false))

    if env["SPARQL_EXPECT_ENTAILMENT_DIFFERENCE"] == "1" {
        #expect(firstData != secondData)
    }
}

@Test
func entailmentRoundTripAcrossConfiguredEndpointsWhenAvailable() async throws {
    let env = ProcessInfo.processInfo.environment
    guard let endpointA = env["SPARQL_ENTAILMENT_ENDPOINT_A_URL"],
          let endpointB = env["SPARQL_ENTAILMENT_ENDPOINT_B_URL"],
          let endpointAURL = URL(string: endpointA),
          let endpointBURL = URL(string: endpointB)
    else {
        return
    }

    let query = SPARQLAskQuery(wherePatterns: ["?s ?p ?o ."])
    let clientA = SPARQLEndpointClient(configuration: SPARQLEndpointConfiguration(queryURL: endpointAURL))
    let clientB = SPARQLEndpointClient(configuration: SPARQLEndpointConfiguration(queryURL: endpointBURL))

    let dataA = try await clientA.executeQuery(query, accept: .jsonResults)
    let dataB = try await clientB.executeQuery(query, accept: .jsonResults)

    let decoder = SPARQLJSONResultDecoder()
    let resultA = try decoder.decodeQueryResult(dataA)
    let resultB = try decoder.decodeQueryResult(dataB)
    #expect(resultA == .boolean(true) || resultA == .boolean(false))
    #expect(resultB == .boolean(true) || resultB == .boolean(false))

    if env["SPARQL_EXPECT_CROSS_ENDPOINT_ENTAILMENT_DIFFERENCE"] == "1" {
        #expect(dataA != dataB)
    }
}
