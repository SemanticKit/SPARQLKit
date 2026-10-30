import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import IRIKit
import RDFCore
import RDFFormats

/// The cases of one conformance run, read from W3C test manifests by
/// ``SPARQLW3CManifestLoader``.
public struct SPARQLConformanceSuite: Sendable {
    public let name: String
    public let cases: [SPARQLConformanceCase]

    public init(name: String, cases: [SPARQLConformanceCase]) {
        self.name = name
        self.cases = cases
    }
}

/// One manifest entry: the test it is an individual of and what the test
/// expects.
public struct SPARQLConformanceCase: Sendable {
    public let id: String
    /// The test class the entry's `rdf:type` names, as its generated
    /// individual: running the case is behaviour on that type.
    public let test: any SPARQLConformanceTest
    public let fixtureFile: String?
    /// The typed query a render case renders: the generated individual of
    /// the class its `sk:queryTemplate` node is typed with.
    public let queryTemplate: (any SPARQLConformanceQueryTemplate)?
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

    public init(
        id: String,
        test: any SPARQLConformanceTest,
        fixtureFile: String? = nil,
        queryTemplate: (any SPARQLConformanceQueryTemplate)? = nil,
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
        self.test = test
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
                try testCase.test.run(testCase, loadFixture: loadFixture)
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
}

/// What every kind of test checks against a case's expectations.
extension SPARQLConformanceCase {
    /// The document the case reads.
    func fixtureData(_ loadFixture: (String) throws -> Data) throws -> Data {
        guard let fixtureFile else {
            throw SPARQLConformanceError.missingFixtureFile(id)
        }
        return try loadFixture(fixtureFile)
    }

    /// The query the case sends: its `sk:query`, or the query document its
    /// manifest entry names.
    func query(_ loadFixture: (String) throws -> Data) throws -> String {
        try queryText ?? document(loadFixture, missing: "queryText", kind: "query")
    }

    /// The update the case sends: its `sk:update`, or the update document
    /// its manifest entry names.
    func update(_ loadFixture: (String) throws -> Data) throws -> String {
        try updateText ?? document(loadFixture, missing: "updateText", kind: "update")
    }

    private func document(_ loadFixture: (String) throws -> Data, missing: String, kind: String) throws -> String {
        guard let fixtureFile else {
            throw SPARQLConformanceError.assertionFailed("Case \(id): missing \(missing).")
        }
        guard let text = String(data: try loadFixture(fixtureFile), encoding: .utf8) else {
            throw SPARQLConformanceError.assertionFailed("Case \(id): \(kind) fixture is not UTF-8.")
        }
        return text
    }

    /// The named graph a Graph Store case addresses.
    func namedGraph() throws -> IRI {
        if let iri = namedGraphs.first {
            return iri
        }
        throw SPARQLConformanceError.assertionFailed("Case \(id): missing named graph IRI for graph-store request.")
    }

    /// The query dataset the case sends.
    var queryOptions: SPARQLQueryRequestOptions {
        SPARQLQueryRequestOptions(defaultGraphs: defaultGraphs, namedGraphs: namedGraphs)
    }

    /// The client protocol cases build their requests with.
    var endpointClient: SPARQLEndpointClient {
        SPARQLEndpointClient(
            configuration: SPARQLEndpointConfiguration(
                queryURL: URL(string: "https://example.org/sparql")!,
                updateURL: URL(string: "https://example.org/update")!
            )
        )
    }

    /// The client Graph Store cases build their requests with.
    var graphStoreClient: SPARQLGraphStoreClient {
        SPARQLGraphStoreClient(
            configuration: SPARQLGraphStoreConfiguration(
                graphStoreURL: URL(string: "https://example.org/graph-store")!
            )
        )
    }

    /// The triples a Graph Store case sends, as N-Triples.
    var graphStoreBody: Data {
        let triple = Graph.Element(
            subject: .iri("http://example.org/s"),
            predicate: "http://example.org/p",
            object: .iri("http://example.org/o")
        )
        return Data(NTriplesEncoder().encode(Graph([triple])).utf8)
    }

    func expectBindings(_ resultSet: SPARQLResultSet) throws {
        if let expectedVariables = expectVariableCount, resultSet.variables.count != expectedVariables {
            throw SPARQLConformanceError.assertionFailed(
                "Case \(id): expected variable count \(expectedVariables), got \(resultSet.variables.count)."
            )
        }
        if let expectedBindings = expectBindingCount, resultSet.bindings.count != expectedBindings {
            throw SPARQLConformanceError.assertionFailed(
                "Case \(id): expected binding count \(expectedBindings), got \(resultSet.bindings.count)."
            )
        }
    }

    func expectBoolean(_ result: SPARQLQueryResult) throws {
        guard case let .boolean(value) = result else {
            throw SPARQLConformanceError.expectedBooleanResult(id)
        }
        if let expected = expectBoolean, expected != value {
            throw SPARQLConformanceError.assertionFailed("Case \(id): expected boolean \(expected), got \(value).")
        }
    }

    func expectRendered(_ rendered: String) throws {
        for expected in expectContains where !rendered.contains(expected) {
            throw SPARQLConformanceError.assertionFailed("Case \(id): missing rendered fragment '\(expected)'.")
        }
    }

    func expectRequest(_ request: URLRequest, method expectedMethod: String) throws {
        if request.httpMethod != expectedMethod {
            throw SPARQLConformanceError.assertionFailed(
                "Case \(id): expected HTTP method \(expectedMethod), got \(request.httpMethod ?? "<nil>")."
            )
        }

        let url = request.url?.absoluteString ?? ""
        for expected in expectURLContains where !url.contains(expected) {
            throw SPARQLConformanceError.assertionFailed("Case \(id): URL missing fragment '\(expected)'. URL=\(url)")
        }

        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        for expected in expectBodyContains where !body.contains(expected) {
            throw SPARQLConformanceError.assertionFailed("Case \(id): body missing fragment '\(expected)'. body=\(body)")
        }

        for expected in expectHeaderContains {
            let parts = expected.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                throw SPARQLConformanceError.assertionFailed(
                    "Case \(id): invalid header expectation '\(expected)'. Use 'Header:fragment'."
                )
            }
            let headerName = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let expectedFragment = String(parts[1]).trimmingCharacters(in: .whitespaces)
            let actual = request.value(forHTTPHeaderField: headerName) ?? ""
            if !actual.contains(expectedFragment) {
                throw SPARQLConformanceError.assertionFailed(
                    "Case \(id): header '\(headerName)' missing fragment '\(expectedFragment)'. actual=\(actual)"
                )
            }
        }
    }
}
