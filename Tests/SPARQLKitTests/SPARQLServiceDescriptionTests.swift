import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import SPARQLKit

@Test
func serviceDescriptionParserExtractsCapabilities() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "service_description", withExtension: "ttl"))
    let turtle = try String(contentsOf: fixtureURL, encoding: .utf8)

    let parsed = try SPARQLServiceDescriptionParser().parseTurtle(turtle)

    #expect(parsed.endpoints.contains("https://example.org/sparql"))
    #expect(parsed.supportedLanguages.contains("http://www.w3.org/ns/sparql-service-description#SPARQL12Query"))
    #expect(parsed.features.contains("http://www.w3.org/ns/sparql-service-description#UnionDefaultGraph"))
    #expect(parsed.resultFormats.contains("http://www.w3.org/ns/formats/SPARQL_Results_JSON"))
    #expect(parsed.resultFormats.contains("http://www.w3.org/ns/formats/Turtle"))
    #expect(parsed.entailmentRegimes.contains("http://www.w3.org/ns/entailment/RDFS"))
}

@Test
func serviceDescriptionSupportsKnownFormats() {
    let capabilities = SPARQLServiceDescription(
        resultFormats: [
            SPARQLAccept.jsonResults.rawValue,
            SPARQLGraphAccept.turtle.rawValue
        ]
    )

    #expect(capabilities.supports(.jsonResults))
    #expect(!capabilities.supports(.xmlResults))
    #expect(capabilities.supports(.turtle))
    #expect(!capabilities.supports(.rdfXML))
}

@Test
func serviceDescriptionSupportsEntailmentRegimes() {
    let capabilities = SPARQLServiceDescription(
        entailmentRegimes: ["http://www.w3.org/ns/entailment/RDFS"]
    )

    #expect(capabilities.supportsEntailment("http://www.w3.org/ns/entailment/RDFS"))
    #expect(!capabilities.supportsEntailment("http://www.w3.org/ns/entailment/Simple"))
}

@Test
func endpointClientRejectsUnsupportedResultFormatFromCapabilities() async throws {
    let session = CapabilityMockSession(statusCode: 200, body: "")
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
        session: session
    )

    let query = SPARQLSelectQuery(
        variables: [Variable(rawValue: "s")],
        wherePatterns: ["?s ?p ?o ."]
    )

    let capabilities = SPARQLServiceDescription(resultFormats: [SPARQLAccept.jsonResults.rawValue])

    await #expect(throws: SPARQLError.invalidRequest("Endpoint service description does not support requested result format.")) {
        _ = try await client.executeQuery(query, accept: .xmlResults, serviceDescription: capabilities)
    }
}

@Test
func endpointClientRejectsUnsupportedEntailmentRegimeFromCapabilities() async throws {
    let session = CapabilityMockSession(statusCode: 200, body: "")
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
        session: session
    )

    let query = SPARQLSelectQuery(
        variables: [Variable(rawValue: "s")],
        wherePatterns: ["?s ?p ?o ."]
    )

    let capabilities = SPARQLServiceDescription(
        resultFormats: [SPARQLAccept.jsonResults.rawValue],
        entailmentRegimes: ["http://www.w3.org/ns/entailment/RDFS"]
    )

    await #expect(throws: SPARQLError.invalidRequest("Endpoint service description does not support requested entailment regime.")) {
        _ = try await client.executeQuery(
            query,
            accept: .jsonResults,
            options: SPARQLQueryRequestOptions(requiredEntailmentRegime: "http://www.w3.org/ns/entailment/Simple"),
            serviceDescription: capabilities
        )
    }
}

@Test
func endpointClientRejectsUnsupportedGraphFormatFromCapabilities() async throws {
    let session = CapabilityMockSession(statusCode: 200, body: "")
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
        session: session
    )

    let query = SPARQLConstructQuery(
        constructPatterns: ["?s ?p ?o ."],
        wherePatterns: ["?s ?p ?o ."]
    )

    let capabilities = SPARQLServiceDescription(resultFormats: [SPARQLGraphAccept.turtle.rawValue])

    await #expect(throws: SPARQLError.invalidRequest("Endpoint service description does not support requested graph format.")) {
        _ = try await client.executeGraphQuery(query, accept: .rdfXML, serviceDescription: capabilities)
    }
}

@Test
func endpointClientAllowsSupportedEntailmentRegimeFromCapabilities() async throws {
    let session = CapabilityMockSession(statusCode: 200, body: "{\"boolean\":true}")
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
        session: session
    )

    let query = SPARQLAskQuery(wherePatterns: ["?s ?p ?o ."])
    let capabilities = SPARQLServiceDescription(
        resultFormats: [SPARQLAccept.jsonResults.rawValue],
        entailmentRegimes: ["http://www.w3.org/ns/entailment/RDFS"]
    )

    let data = try await client.executeQuery(
        query,
        accept: .jsonResults,
        options: SPARQLQueryRequestOptions(requiredEntailmentRegime: "http://www.w3.org/ns/entailment/RDFS"),
        serviceDescription: capabilities
    )

    #expect(String(data: data, encoding: .utf8) == "{\"boolean\":true}")
}

@Test
func endpointClientDoesNotGateEntailmentWithoutServiceDescription() async throws {
    let session = CapabilityMockSession(statusCode: 200, body: "{\"boolean\":true}")
    let client = SPARQLEndpointClient(
        configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
        session: session
    )

    let query = SPARQLAskQuery(wherePatterns: ["?s ?p ?o ."])
    let data = try await client.executeQuery(
        query,
        accept: .jsonResults,
        options: SPARQLQueryRequestOptions(requiredEntailmentRegime: "http://www.w3.org/ns/entailment/D")
    )

    #expect(String(data: data, encoding: .utf8) == "{\"boolean\":true}")
}

private final class CapabilityMockSession: URLSessioning, @unchecked Sendable {
    private let responseData: Data
    private let responseCode: Int

    init(statusCode: Int, body: String) {
        self.responseCode = statusCode
        self.responseData = Data(body.utf8)
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        (
            responseData,
            HTTPURLResponse(url: request.url!, statusCode: responseCode, httpVersion: nil, headerFields: nil)!
        )
    }
}
