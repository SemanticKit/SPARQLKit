import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import IRIKit
import RDFCore
import RDFFormats
import RDFKit

public struct SPARQLConformanceSuite: Codable, Sendable {
    public let name: String
    public let cases: [SPARQLConformanceCase]

    public init(name: String, cases: [SPARQLConformanceCase]) {
        self.name = name
        self.cases = cases
    }

    public static func decode(from data: Data) throws -> SPARQLConformanceSuite {
        try JSONDecoder().decode(SPARQLConformanceSuite.self, from: data)
    }
}

public struct SPARQLConformanceCase: Codable, Sendable {
    public let id: String
    public let operation: SPARQLConformanceOperation
    public let fixtureFile: String?
    public let queryTemplate: SPARQLConformanceQueryTemplate?
    public let queryText: String?
    public let updateText: String?
    public let defaultGraphs: [IRI]
    public let namedGraphs: [IRI]
    public let usingGraphs: [IRI]
    public let usingNamedGraphs: [IRI]

    public let expectVariableCount: Int?
    public let expectBindingCount: Int?
    public let expectBoolean: Bool?
    public let expectContains: [String]
    public let expectURLContains: [String]
    public let expectBodyContains: [String]
    public let expectHeaderContains: [String]

    private enum CodingKeys: String, CodingKey {
        case id
        case operation
        case fixtureFile
        case queryTemplate
        case queryText
        case updateText
        case defaultGraphs
        case namedGraphs
        case usingGraphs
        case usingNamedGraphs
        case expectVariableCount
        case expectBindingCount
        case expectBoolean
        case expectContains
        case expectURLContains
        case expectBodyContains
        case expectHeaderContains
    }

    public init(
        id: String,
        operation: SPARQLConformanceOperation,
        fixtureFile: String? = nil,
        queryTemplate: SPARQLConformanceQueryTemplate? = nil,
        queryText: String? = nil,
        updateText: String? = nil,
        defaultGraphs: [IRI] = [],
        namedGraphs: [IRI] = [],
        usingGraphs: [IRI] = [],
        usingNamedGraphs: [IRI] = [],
        expectVariableCount: Int? = nil,
        expectBindingCount: Int? = nil,
        expectBoolean: Bool? = nil,
        expectContains: [String] = [],
        expectURLContains: [String] = [],
        expectBodyContains: [String] = [],
        expectHeaderContains: [String] = []
    ) {
        self.id = id
        self.operation = operation
        self.fixtureFile = fixtureFile
        self.queryTemplate = queryTemplate
        self.queryText = queryText
        self.updateText = updateText
        self.defaultGraphs = defaultGraphs
        self.namedGraphs = namedGraphs
        self.usingGraphs = usingGraphs
        self.usingNamedGraphs = usingNamedGraphs
        self.expectVariableCount = expectVariableCount
        self.expectBindingCount = expectBindingCount
        self.expectBoolean = expectBoolean
        self.expectContains = expectContains
        self.expectURLContains = expectURLContains
        self.expectBodyContains = expectBodyContains
        self.expectHeaderContains = expectHeaderContains
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        operation = try container.decode(SPARQLConformanceOperation.self, forKey: .operation)
        fixtureFile = try container.decodeIfPresent(String.self, forKey: .fixtureFile)
        queryTemplate = try container.decodeIfPresent(SPARQLConformanceQueryTemplate.self, forKey: .queryTemplate)
        queryText = try container.decodeIfPresent(String.self, forKey: .queryText)
        updateText = try container.decodeIfPresent(String.self, forKey: .updateText)
        defaultGraphs = try container.decodeIfPresent([IRI].self, forKey: .defaultGraphs) ?? []
        namedGraphs = try container.decodeIfPresent([IRI].self, forKey: .namedGraphs) ?? []
        usingGraphs = try container.decodeIfPresent([IRI].self, forKey: .usingGraphs) ?? []
        usingNamedGraphs = try container.decodeIfPresent([IRI].self, forKey: .usingNamedGraphs) ?? []
        expectVariableCount = try container.decodeIfPresent(Int.self, forKey: .expectVariableCount)
        expectBindingCount = try container.decodeIfPresent(Int.self, forKey: .expectBindingCount)
        expectBoolean = try container.decodeIfPresent(Bool.self, forKey: .expectBoolean)
        expectContains = try container.decodeIfPresent([String].self, forKey: .expectContains) ?? []
        expectURLContains = try container.decodeIfPresent([String].self, forKey: .expectURLContains) ?? []
        expectBodyContains = try container.decodeIfPresent([String].self, forKey: .expectBodyContains) ?? []
        expectHeaderContains = try container.decodeIfPresent([String].self, forKey: .expectHeaderContains) ?? []
    }
}

public enum SPARQLConformanceOperation: String, Codable, Sendable {
    case decodeJSONBindings
    case decodeJSONBoolean
    case decodeXMLBindings
    case decodeXMLBoolean
    case decodeCSVBindings
    case decodeTSVBindings
    case renderQuery
    case buildGETQueryRequest
    case buildPOSTQueryRequest
    case buildGETGraphQueryRequest
    case buildPOSTGraphQueryRequest
    case buildPOSTUpdateRequest
    case buildGETDefaultGraphStoreRequest
    case buildHEADNamedGraphStoreRequest
    case buildPOSTServiceGraphStoreRequest
    case buildPUTNamedGraphStoreRequest
    case buildDELETENamedGraphStoreRequest
}

public enum SPARQLConformanceQueryTemplate: String, Codable, Sendable {
    case basicSelect
}

public struct SPARQLConformanceCaseResult: Sendable {
    public let id: String
    public let passed: Bool
    public let expectedFailure: Bool
    public let message: String?

    public init(id: String, passed: Bool, expectedFailure: Bool = false, message: String? = nil) {
        self.id = id
        self.passed = passed
        self.expectedFailure = expectedFailure
        self.message = message
    }
}

public struct SPARQLConformanceReport: Sendable {
    public let suiteName: String
    public let results: [SPARQLConformanceCaseResult]

    public init(suiteName: String, results: [SPARQLConformanceCaseResult]) {
        self.suiteName = suiteName
        self.results = results
    }

    public var passedCount: Int { results.filter(\.passed).count }
    public var expectedFailureCount: Int { results.filter(\.expectedFailure).count }
    public var failedCount: Int { results.filter { !$0.passed && !$0.expectedFailure }.count }
    public var allPassed: Bool { failedCount == 0 }
}

public enum SPARQLConformanceError: Error, Equatable, Sendable {
    case missingFixtureFile(String)
    case missingQueryTemplate(String)
    case expectedBindingsResult(String)
    case expectedBooleanResult(String)
    case assertionFailed(String)
}

public struct SPARQLConformanceRunner {
    public init() {}

    public func run(
        suite: SPARQLConformanceSuite,
        expectedFailures: Set<String> = [],
        loadFixture: (String) throws -> Data
    ) -> SPARQLConformanceReport {
        let results = suite.cases.map { testCase in
            do {
                try runCase(testCase, loadFixture: loadFixture)
                if expectedFailures.contains(testCase.id) {
                    return SPARQLConformanceCaseResult(
                        id: testCase.id,
                        passed: false,
                        expectedFailure: false,
                        message: "XPASS: case passed but is marked as expected failure."
                    )
                }
                return SPARQLConformanceCaseResult(id: testCase.id, passed: true)
            } catch {
                if expectedFailures.contains(testCase.id) {
                    return SPARQLConformanceCaseResult(
                        id: testCase.id,
                        passed: true,
                        expectedFailure: true,
                        message: "XFAIL: \(error)"
                    )
                }
                return SPARQLConformanceCaseResult(
                    id: testCase.id,
                    passed: false,
                    message: String(describing: error)
                )
            }
        }

        return SPARQLConformanceReport(suiteName: suite.name, results: results)
    }

    private func runCase(
        _ testCase: SPARQLConformanceCase,
        loadFixture: (String) throws -> Data
    ) throws {
        switch testCase.operation {
        case .decodeJSONBindings:
            let data = try fixtureData(for: testCase, loadFixture: loadFixture)
            let result = try SPARQLJSONResultDecoder().decode(data)
            try assertBindings(result, testCase: testCase)

        case .decodeJSONBoolean:
            let data = try fixtureData(for: testCase, loadFixture: loadFixture)
            let result = try SPARQLJSONResultDecoder().decodeQueryResult(data)
            guard case let .boolean(value) = result else {
                throw SPARQLConformanceError.expectedBooleanResult(testCase.id)
            }
            if let expected = testCase.expectBoolean, expected != value {
                throw SPARQLConformanceError.assertionFailed(
                    "Case \(testCase.id): expected boolean \(expected), got \(value)."
                )
            }

        case .decodeXMLBindings:
            let data = try fixtureData(for: testCase, loadFixture: loadFixture)
            let result = try SPARQLXMLResultDecoder().decode(data)
            try assertBindings(result, testCase: testCase)

        case .decodeXMLBoolean:
            let data = try fixtureData(for: testCase, loadFixture: loadFixture)
            let result = try SPARQLXMLResultDecoder().decodeQueryResult(data)
            guard case let .boolean(value) = result else {
                throw SPARQLConformanceError.expectedBooleanResult(testCase.id)
            }
            if let expected = testCase.expectBoolean, expected != value {
                throw SPARQLConformanceError.assertionFailed(
                    "Case \(testCase.id): expected boolean \(expected), got \(value)."
                )
            }

        case .decodeCSVBindings:
            let data = try fixtureData(for: testCase, loadFixture: loadFixture)
            let result = try SPARQLDelimitedResultsDecoder().decodeCSV(data)
            try assertBindings(result, testCase: testCase)

        case .decodeTSVBindings:
            let data = try fixtureData(for: testCase, loadFixture: loadFixture)
            let result = try SPARQLDelimitedResultsDecoder().decodeTSV(data)
            try assertBindings(result, testCase: testCase)

        case .renderQuery:
            let rendered = try renderTemplate(for: testCase)
            for expected in testCase.expectContains {
                if !rendered.contains(expected) {
                    throw SPARQLConformanceError.assertionFailed(
                        "Case \(testCase.id): missing rendered fragment '\(expected)'."
                    )
                }
            }

        case .buildGETQueryRequest:
            let query = try requireQueryText(testCase, loadFixture: loadFixture)
            let client = makeProtocolClient()
            let accept = SPARQLAccept.jsonResults.rawValue
            let request = try client.makeQueryRequest(
                query,
                accept: accept,
                method: .get,
                options: SPARQLQueryRequestOptions(
                    defaultGraphs: testCase.defaultGraphs,
                    namedGraphs: testCase.namedGraphs
                )
            )
            try assertRequest(request, testCase: testCase, expectedMethod: "GET")

        case .buildPOSTQueryRequest:
            let query = try requireQueryText(testCase, loadFixture: loadFixture)
            let client = makeProtocolClient()
            let accept = SPARQLAccept.jsonResults.rawValue
            let request = try client.makeQueryRequest(
                query,
                accept: accept,
                method: .post,
                options: SPARQLQueryRequestOptions(
                    defaultGraphs: testCase.defaultGraphs,
                    namedGraphs: testCase.namedGraphs
                )
            )
            try assertRequest(request, testCase: testCase, expectedMethod: "POST")

        case .buildGETGraphQueryRequest:
            let query = try requireQueryText(testCase, loadFixture: loadFixture)
            let client = makeProtocolClient()
            let request = try client.makeQueryRequest(
                query,
                accept: SPARQLGraphAccept.turtle.rawValue,
                method: .get,
                options: SPARQLQueryRequestOptions(
                    defaultGraphs: testCase.defaultGraphs,
                    namedGraphs: testCase.namedGraphs
                )
            )
            try assertRequest(request, testCase: testCase, expectedMethod: "GET")

        case .buildPOSTGraphQueryRequest:
            let query = try requireQueryText(testCase, loadFixture: loadFixture)
            let client = makeProtocolClient()
            let request = try client.makeQueryRequest(
                query,
                accept: SPARQLGraphAccept.turtle.rawValue,
                method: .post,
                options: SPARQLQueryRequestOptions(
                    defaultGraphs: testCase.defaultGraphs,
                    namedGraphs: testCase.namedGraphs
                )
            )
            try assertRequest(request, testCase: testCase, expectedMethod: "POST")

        case .buildPOSTUpdateRequest:
            let update = try requireUpdateText(testCase, loadFixture: loadFixture)
            let client = makeProtocolClient()
            let request = try client.makeUpdateRequest(
                update,
                options: SPARQLUpdateRequestOptions(
                    usingGraphs: testCase.usingGraphs,
                    usingNamedGraphs: testCase.usingNamedGraphs
                )
            )
            try assertRequest(request, testCase: testCase, expectedMethod: "POST")

        case .buildGETDefaultGraphStoreRequest:
            let client = makeGraphStoreClient()
            let request = try client.makeRequest(
                method: "GET",
                graph: .defaultGraph,
                accept: SPARQLGraphAccept.turtle.rawValue
            )
            try assertRequest(request, testCase: testCase, expectedMethod: "GET")

        case .buildHEADNamedGraphStoreRequest:
            let iri = try requireNamedGraphIRI(testCase)
            let client = makeGraphStoreClient()
            let request = try client.makeRequest(
                method: "HEAD",
                graph: .named(iri)
            )
            try assertRequest(request, testCase: testCase, expectedMethod: "HEAD")

        case .buildPOSTServiceGraphStoreRequest:
            let client = makeGraphStoreClient()
            let request = try client.makeRequest(
                method: "POST",
                graph: .service,
                contentType: SPARQLGraphAccept.ntriples.rawValue,
                body: Data(NTriplesEncoder().encode(Graph([Self.graphStoreTriple])).utf8)
            )
            try assertRequest(request, testCase: testCase, expectedMethod: "POST")

        case .buildPUTNamedGraphStoreRequest:
            let iri = try requireNamedGraphIRI(testCase)
            let client = makeGraphStoreClient()
            let request = try client.makeRequest(
                method: "PUT",
                graph: .named(iri),
                contentType: SPARQLGraphAccept.ntriples.rawValue,
                body: Data(NTriplesEncoder().encode(Graph([Self.graphStoreTriple])).utf8)
            )
            try assertRequest(request, testCase: testCase, expectedMethod: "PUT")

        case .buildDELETENamedGraphStoreRequest:
            let iri = try requireNamedGraphIRI(testCase)
            let client = makeGraphStoreClient()
            let request = try client.makeRequest(
                method: "DELETE",
                graph: .named(iri)
            )
            try assertRequest(request, testCase: testCase, expectedMethod: "DELETE")
        }
    }

    private func fixtureData(
        for testCase: SPARQLConformanceCase,
        loadFixture: (String) throws -> Data
    ) throws -> Data {
        guard let fixtureFile = testCase.fixtureFile else {
            throw SPARQLConformanceError.missingFixtureFile(testCase.id)
        }
        return try loadFixture(fixtureFile)
    }

    private func renderTemplate(for testCase: SPARQLConformanceCase) throws -> String {
        guard let template = testCase.queryTemplate else {
            throw SPARQLConformanceError.missingQueryTemplate(testCase.id)
        }

        switch template {
        case .basicSelect:
            let query = SPARQLSelectQuery(
                ["s", "o"],
                where: [.triple(SPARQLTriplePattern(.variable("s"), .property(RDF.value.sparql), .variable("o")))],
                limit: 5
            )
            return query.render()
        }
    }

    private func assertBindings(_ resultSet: SPARQLResultSet, testCase: SPARQLConformanceCase) throws {
        if let expectedVariables = testCase.expectVariableCount,
           resultSet.variables.count != expectedVariables
        {
            throw SPARQLConformanceError.assertionFailed(
                "Case \(testCase.id): expected variable count \(expectedVariables), got \(resultSet.variables.count)."
            )
        }

        if let expectedBindings = testCase.expectBindingCount,
           resultSet.bindings.count != expectedBindings
        {
            throw SPARQLConformanceError.assertionFailed(
                "Case \(testCase.id): expected binding count \(expectedBindings), got \(resultSet.bindings.count)."
            )
        }
    }

    private func makeProtocolClient() -> SPARQLEndpointClient {
        SPARQLEndpointClient(
            configuration: SPARQLEndpointConfiguration(
                queryURL: URL(string: "https://example.org/sparql")!,
                updateURL: URL(string: "https://example.org/update")!
            )
        )
    }

    private func makeGraphStoreClient() -> SPARQLGraphStoreClient {
        SPARQLGraphStoreClient(
            configuration: SPARQLGraphStoreConfiguration(
                graphStoreURL: URL(string: "https://example.org/graph-store")!
            )
        )
    }

    private func requireQueryText(
        _ testCase: SPARQLConformanceCase,
        loadFixture: (String) throws -> Data
    ) throws -> String {
        if let query = testCase.queryText {
            return query
        }
        guard let fixtureFile = testCase.fixtureFile else {
            throw SPARQLConformanceError.assertionFailed("Case \(testCase.id): missing queryText.")
        }
        let data = try loadFixture(fixtureFile)
        guard let query = String(data: data, encoding: .utf8) else {
            throw SPARQLConformanceError.assertionFailed("Case \(testCase.id): query fixture is not UTF-8.")
        }
        return query
    }

    private func requireUpdateText(
        _ testCase: SPARQLConformanceCase,
        loadFixture: (String) throws -> Data
    ) throws -> String {
        if let update = testCase.updateText {
            return update
        }
        guard let fixtureFile = testCase.fixtureFile else {
            throw SPARQLConformanceError.assertionFailed("Case \(testCase.id): missing updateText.")
        }
        let data = try loadFixture(fixtureFile)
        guard let update = String(data: data, encoding: .utf8) else {
            throw SPARQLConformanceError.assertionFailed("Case \(testCase.id): update fixture is not UTF-8.")
        }
        return update
    }

    private func requireNamedGraphIRI(_ testCase: SPARQLConformanceCase) throws -> IRI {
        if let iri = testCase.namedGraphs.first {
            return iri
        }
        throw SPARQLConformanceError.assertionFailed("Case \(testCase.id): missing named graph IRI for graph-store request.")
    }

    /// The triple a graph store case sends.
    static let graphStoreTriple = Graph.Element(
        subject: .iri("http://example.org/s"),
        predicate: "http://example.org/p",
        object: .iri("http://example.org/o")
    )

    private func assertRequest(
        _ request: URLRequest,
        testCase: SPARQLConformanceCase,
        expectedMethod: String
    ) throws {
        if request.httpMethod != expectedMethod {
            throw SPARQLConformanceError.assertionFailed(
                "Case \(testCase.id): expected HTTP method \(expectedMethod), got \(request.httpMethod ?? "<nil>")."
            )
        }

        let url = request.url?.absoluteString ?? ""
        for expected in testCase.expectURLContains where !url.contains(expected) {
            throw SPARQLConformanceError.assertionFailed(
                "Case \(testCase.id): URL missing fragment '\(expected)'. URL=\(url)"
            )
        }

        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        for expected in testCase.expectBodyContains where !body.contains(expected) {
            throw SPARQLConformanceError.assertionFailed(
                "Case \(testCase.id): body missing fragment '\(expected)'. body=\(body)"
            )
        }

        for expected in testCase.expectHeaderContains {
            let parts = expected.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                throw SPARQLConformanceError.assertionFailed(
                    "Case \(testCase.id): invalid header expectation '\(expected)'. Use 'Header:fragment'."
                )
            }
            let headerName = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let expectedFragment = String(parts[1]).trimmingCharacters(in: .whitespaces)
            let actual = request.value(forHTTPHeaderField: headerName) ?? ""
            if !actual.contains(expectedFragment) {
                throw SPARQLConformanceError.assertionFailed(
                    "Case \(testCase.id): header '\(headerName)' missing fragment '\(expectedFragment)'. actual=\(actual)"
                )
            }
        }
    }
}
