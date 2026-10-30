import Foundation

public struct SPARQLW3CManifestIndex: Codable, Sendable {
    public let name: String
    public let manifests: [String]
    public let expectedFailures: [String]

    private enum CodingKeys: String, CodingKey {
        case name
        case manifests
        case expectedFailures
    }

    public init(name: String, manifests: [String], expectedFailures: [String] = []) {
        self.name = name
        self.manifests = manifests
        self.expectedFailures = expectedFailures
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        manifests = try container.decode([String].self, forKey: .manifests)
        expectedFailures = try container.decodeIfPresent([String].self, forKey: .expectedFailures) ?? []
    }
}

public struct SPARQLConformanceExecutionPlan: Sendable {
    public let suite: SPARQLConformanceSuite
    public let expectedFailures: Set<String>

    public init(suite: SPARQLConformanceSuite, expectedFailures: Set<String>) {
        self.suite = suite
        self.expectedFailures = expectedFailures
    }
}

public extension SPARQLW3CManifestLoader {
    func loadSuite(
        fromIndexData data: Data,
        baseURL: URL?,
        loadManifestFile: @escaping (String) throws -> Data
    ) throws -> SPARQLConformanceSuite {
        let index = try JSONDecoder().decode(SPARQLW3CManifestIndex.self, from: data)
        return try loadSuite(fromIndex: index, baseURL: baseURL, loadManifestFile: loadManifestFile)
    }

    func loadPlan(
        fromIndexData data: Data,
        baseURL: URL?,
        loadManifestFile: @escaping (String) throws -> Data
    ) throws -> SPARQLConformanceExecutionPlan {
        let index = try JSONDecoder().decode(SPARQLW3CManifestIndex.self, from: data)
        return try loadPlan(fromIndex: index, baseURL: baseURL, loadManifestFile: loadManifestFile)
    }

    func loadSuite(
        fromIndex index: SPARQLW3CManifestIndex,
        baseURL: URL?,
        loadManifestFile: @escaping (String) throws -> Data
    ) throws -> SPARQLConformanceSuite {
        var mergedCases: [SPARQLConformanceCase] = []

        for manifestFile in index.manifests {
            let manifestData = try loadManifestFile(manifestFile)
            let manifestURL = URL(string: manifestFile, relativeTo: baseURL)?.absoluteURL
            let suite = try loadSuite(
                from: manifestData,
                baseURL: manifestURL,
                loadIncludedManifest: loadManifestFile
            )
            mergedCases.append(contentsOf: suite.cases)
        }

        return SPARQLConformanceSuite(name: index.name, cases: mergedCases)
    }

    func loadPlan(
        fromIndex index: SPARQLW3CManifestIndex,
        baseURL: URL?,
        loadManifestFile: @escaping (String) throws -> Data
    ) throws -> SPARQLConformanceExecutionPlan {
        let suite = try loadSuite(fromIndex: index, baseURL: baseURL, loadManifestFile: loadManifestFile)
        return SPARQLConformanceExecutionPlan(
            suite: suite,
            expectedFailures: Set(index.expectedFailures)
        )
    }
}
