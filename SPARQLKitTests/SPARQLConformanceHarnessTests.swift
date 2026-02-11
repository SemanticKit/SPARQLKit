import Foundation
import Testing
@testable import SPARQLKit

@Test
func conformanceRunnerExecutesSmokeSuiteFromFixture() throws {
    let fixtureData = try loadFixture(named: "conformance_smoke_suite", ext: "json")
    let suite = try SPARQLConformanceSuite.decode(from: fixtureData)
    let runner = SPARQLConformanceRunner()

    let report = runner.run(suite: suite) { fileName in
        try loadFixtureFile(fileName)
    }

    #expect(report.results.count == 5)
    #expect(report.allPassed)
    #expect(report.failedCount == 0)
}

@Test
func conformanceRunnerReportsCaseFailures() throws {
    let suite = SPARQLConformanceSuite(
        name: "failing suite",
        cases: [
            SPARQLConformanceCase(
                id: "bad-count",
                operation: .decodeJSONBindings,
                fixtureFile: "select_result.json",
                expectBindingCount: 999
            )
        ]
    )

    let report = SPARQLConformanceRunner().run(suite: suite) { fileName in
        try loadFixtureFile(fileName)
    }

    #expect(report.results.count == 1)
    #expect(!report.allPassed)
    #expect(report.failedCount == 1)
    #expect(report.results.first?.passed == false)
}

@Test
func conformanceRunnerMarksExpectedFailuresAsXFail() throws {
    let suite = SPARQLConformanceSuite(
        name: "xfail suite",
        cases: [
            SPARQLConformanceCase(
                id: "known-failure",
                operation: .decodeJSONBindings,
                fixtureFile: "select_result.json",
                expectBindingCount: 999
            )
        ]
    )

    let report = SPARQLConformanceRunner().run(
        suite: suite,
        expectedFailures: ["known-failure"]
    ) { fileName in
        try loadFixtureFile(fileName)
    }

    #expect(report.results.count == 1)
    #expect(report.allPassed)
    #expect(report.failedCount == 0)
    #expect(report.expectedFailureCount == 1)
    #expect(report.results.first?.expectedFailure == true)
}

@Test
func conformanceRunnerMarksUnexpectedPassAsXPass() throws {
    let suite = SPARQLConformanceSuite(
        name: "xpass suite",
        cases: [
            SPARQLConformanceCase(
                id: "was-expected-to-fail",
                operation: .decodeJSONBindings,
                fixtureFile: "select_result.json",
                expectBindingCount: 3
            )
        ]
    )

    let report = SPARQLConformanceRunner().run(
        suite: suite,
        expectedFailures: ["was-expected-to-fail"]
    ) { fileName in
        try loadFixtureFile(fileName)
    }

    #expect(report.results.count == 1)
    #expect(!report.allPassed)
    #expect(report.failedCount == 1)
    #expect(report.expectedFailureCount == 0)
    #expect(report.results.first?.passed == false)
    #expect(report.results.first?.expectedFailure == false)
}

@Test
func conformanceRunnerBuildsGraphQueryProtocolRequests() throws {
    let suite = SPARQLConformanceSuite(
        name: "graph protocol suite",
        cases: [
            SPARQLConformanceCase(
                id: "graph-get",
                operation: .buildGETGraphQueryRequest,
                queryText: "CONSTRUCT { ?s ?p ?o . } WHERE { ?s ?p ?o . } LIMIT 1",
                expectURLContains: ["query=CONSTRUCT", "default-graph-uri=https://example.org/graph/default"]
            ),
            SPARQLConformanceCase(
                id: "graph-post",
                operation: .buildPOSTGraphQueryRequest,
                queryText: "DESCRIBE <http://example.org/s>",
                namedGraphURIs: ["https://example.org/graph/named"],
                expectBodyContains: ["query=DESCRIBE%20%3Chttp%3A%2F%2Fexample.org%2Fs%3E", "named-graph-uri=https%3A%2F%2Fexample.org%2Fgraph%2Fnamed"]
            )
        ]
    )

    let adjustedCases = [
        SPARQLConformanceCase(
            id: suite.cases[0].id,
            operation: suite.cases[0].operation,
            queryText: suite.cases[0].queryText,
            defaultGraphURIs: ["https://example.org/graph/default"],
            expectURLContains: suite.cases[0].expectURLContains
        ),
        suite.cases[1]
    ]
    let adjustedSuite = SPARQLConformanceSuite(name: suite.name, cases: adjustedCases)

    let report = SPARQLConformanceRunner().run(suite: adjustedSuite) { fileName in
        try loadFixtureFile(fileName)
    }

    #expect(report.results.count == 2)
    #expect(report.allPassed)
}

@Test
func conformanceRunnerAutoUsesGraphAcceptForConstructInGenericQueryOperation() throws {
    let suite = SPARQLConformanceSuite(
        name: "generic query graph accept",
        cases: [
            SPARQLConformanceCase(
                id: "construct-over-generic-query-op",
                operation: .buildPOSTQueryRequest,
                queryText: "CONSTRUCT { ?s ?p ?o . } WHERE { ?s ?p ?o . }",
                expectHeaderContains: ["Accept:text/turtle"]
            )
        ]
    )

    let report = SPARQLConformanceRunner().run(suite: suite) { fileName in
        try loadFixtureFile(fileName)
    }
    #expect(report.results.count == 1)
    #expect(report.allPassed)
}

@Test
func conformanceRunnerBuildsGraphStoreProtocolRequests() throws {
    let suite = SPARQLConformanceSuite(
        name: "graph store protocol suite",
        cases: [
            SPARQLConformanceCase(
                id: "gsp-get-default",
                operation: .buildGETDefaultGraphStoreRequest,
                expectURLContains: ["default"],
                expectBodyContains: []
            ),
            SPARQLConformanceCase(
                id: "gsp-head-named",
                operation: .buildHEADNamedGraphStoreRequest,
                namedGraphURIs: ["https://example.org/graphs/named"],
                expectURLContains: ["graph=https://example.org/graphs/named"]
            ),
            SPARQLConformanceCase(
                id: "gsp-post-service",
                operation: .buildPOSTServiceGraphStoreRequest,
                expectBodyContains: ["<s> <p> <o> ."]
            ),
            SPARQLConformanceCase(
                id: "gsp-put-named",
                operation: .buildPUTNamedGraphStoreRequest,
                namedGraphURIs: ["https://example.org/graphs/named-put"],
                expectURLContains: ["graph=https://example.org/graphs/named-put"],
                expectBodyContains: ["<s> <p> <o> ."]
            ),
            SPARQLConformanceCase(
                id: "gsp-delete-named",
                operation: .buildDELETENamedGraphStoreRequest,
                namedGraphURIs: ["https://example.org/graphs/named-delete"],
                expectURLContains: ["graph=https://example.org/graphs/named-delete"]
            )
        ]
    )

    let report = SPARQLConformanceRunner().run(suite: suite) { fileName in
        try loadFixtureFile(fileName)
    }

    #expect(report.results.count == 5)
    #expect(report.allPassed)
}

private func loadFixtureFile(_ fileName: String) throws -> Data {
    let stem = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
    let ext = URL(fileURLWithPath: fileName).pathExtension
    return try loadFixture(named: stem, ext: ext)
}

private func loadFixture(named name: String, ext: String) throws -> Data {
    let fixtureURL = try #require(Bundle.module.url(forResource: name, withExtension: ext))
    return try Data(contentsOf: fixtureURL)
}
