import Foundation
import SPARQLConformance
import Testing
@testable import SPARQLKit

@Suite("Conformance runner", .tags(.conformance))
struct SPARQLConformanceHarnessTests {
    let runner = SPARQLConformanceRunner()

    @Test("The smoke suite passes")
    func smokeSuitePasses() throws {
        let suite = try SPARQLW3CManifestLoader().loadSuite(
            from: try fixture("conformance_smoke_suite.ttl"),
            baseURL: URL(string: "https://example.org/manifests/conformance_smoke_suite.ttl")
        )
        let report = runner.run(suite: suite, loadFixture: fixture)

        #expect(report.results.count == 5)
        #expect(report.allPassed)
    }

    @Test("A failing case is reported")
    func failingCaseIsReported() {
        let suite = SPARQLConformanceSuite(name: "failing", cases: [
            SPARQLConformanceCase(id: "bad-count", test: SPARQLConformance.DecodeJSONBindingsTestIndividual(), fixtureFile: "select_result.json", expectBindingCount: 999)
        ])
        let report = runner.run(suite: suite, loadFixture: fixture)

        #expect(!report.allPassed)
        #expect(report.failedCount == 1)
        #expect(report.results.first?.passed == false)
    }

    @Test("An expected failure that fails is XFAIL")
    func expectedFailureIsXFail() {
        let suite = SPARQLConformanceSuite(name: "xfail", cases: [
            SPARQLConformanceCase(id: "known-failure", test: SPARQLConformance.DecodeJSONBindingsTestIndividual(), fixtureFile: "select_result.json", expectBindingCount: 999)
        ])
        let report = runner.run(suite: suite, expectedFailures: ["known-failure"], loadFixture: fixture)

        #expect(report.allPassed)
        #expect(report.expectedFailureCount == 1)
        #expect(report.results.first?.expectedFailure == true)
    }

    @Test("An expected failure that passes is XPASS, which fails the run")
    func unexpectedPassIsXPass() {
        let suite = SPARQLConformanceSuite(name: "xpass", cases: [
            SPARQLConformanceCase(id: "was-expected-to-fail", test: SPARQLConformance.DecodeJSONBindingsTestIndividual(), fixtureFile: "select_result.json", expectBindingCount: 3)
        ])
        let report = runner.run(suite: suite, expectedFailures: ["was-expected-to-fail"], loadFixture: fixture)

        #expect(!report.allPassed)
        #expect(report.failedCount == 1)
        #expect(report.expectedFailureCount == 0)
        #expect(report.results.first?.message?.hasPrefix("XPASS") == true)
    }

    @Test("Graph query cases ask for Turtle and carry their dataset")
    func graphQueryCases() {
        let suite = SPARQLConformanceSuite(name: "graph protocol", cases: [
            SPARQLConformanceCase(
                id: "graph-get",
                test: SPARQLConformance.ProtocolGetGraphQueryRequestTestIndividual(),
                queryText: "CONSTRUCT { ?s ?p ?o . } WHERE { ?s ?p ?o . } LIMIT 1",
                defaultGraphs: ["https://example.org/graph/default"],
                expectURLContains: ["query=CONSTRUCT", "default-graph-uri=https%3A%2F%2Fexample.org%2Fgraph%2Fdefault"],
                expectHeaderContains: ["Accept:text/turtle"]
            ),
            SPARQLConformanceCase(
                id: "graph-post",
                test: SPARQLConformance.ProtocolPostGraphQueryRequestTestIndividual(),
                queryText: "DESCRIBE <http://example.org/s>",
                namedGraphs: ["https://example.org/graph/named"],
                expectBodyContains: ["query=DESCRIBE%20%3Chttp%3A%2F%2Fexample.org%2Fs%3E", "named-graph-uri=https%3A%2F%2Fexample.org%2Fgraph%2Fnamed"]
            ),
            SPARQLConformanceCase(
                id: "construct-after-one-line-prologue",
                test: SPARQLConformance.ProtocolPostGraphQueryRequestTestIndividual(),
                queryText: "PREFIX ex: <http://example.org/> CONSTRUCT { ?s ex:p ?o } WHERE { ?s ex:p ?o }",
                expectHeaderContains: ["Accept:text/turtle"]
            ),
            SPARQLConformanceCase(
                id: "results-query",
                test: SPARQLConformance.ProtocolPostQueryRequestTestIndividual(),
                queryText: "PREFIX ex: <http://example.org/> SELECT * WHERE { ?s ex:p ?o }",
                expectHeaderContains: ["Accept:application/sparql-results+json"]
            )
        ])
        let report = runner.run(suite: suite, loadFixture: fixture)

        #expect(report.results.count == 4)
        #expect(report.allPassed, "\(report.results.compactMap(\.message))")
    }

    @Test("Graph Store cases build their requests")
    func graphStoreCases() {
        let body = "<http://example.org/s> <http://example.org/p> <http://example.org/o> ."
        let suite = SPARQLConformanceSuite(name: "graph store protocol", cases: [
            SPARQLConformanceCase(id: "gsp-get-default", test: SPARQLConformance.GraphStoreGetDefaultRequestTestIndividual(), expectURLContains: ["default"]),
            SPARQLConformanceCase(
                id: "gsp-head-named",
                test: SPARQLConformance.GraphStoreHeadNamedRequestTestIndividual(),
                namedGraphs: ["https://example.org/graphs/named"],
                expectURLContains: ["graph=https%3A%2F%2Fexample.org%2Fgraphs%2Fnamed"]
            ),
            SPARQLConformanceCase(id: "gsp-post-service", test: SPARQLConformance.GraphStorePostServiceRequestTestIndividual(), expectBodyContains: [body]),
            SPARQLConformanceCase(
                id: "gsp-put-named",
                test: SPARQLConformance.GraphStorePutNamedRequestTestIndividual(),
                namedGraphs: ["https://example.org/graphs/named-put"],
                expectURLContains: ["graph=https%3A%2F%2Fexample.org%2Fgraphs%2Fnamed-put"],
                expectBodyContains: [body]
            ),
            SPARQLConformanceCase(
                id: "gsp-delete-named",
                test: SPARQLConformance.GraphStoreDeleteNamedRequestTestIndividual(),
                namedGraphs: ["https://example.org/graphs/named-delete"],
                expectURLContains: ["graph=https%3A%2F%2Fexample.org%2Fgraphs%2Fnamed-delete"]
            )
        ])
        let report = runner.run(suite: suite, loadFixture: fixture)

        #expect(report.results.count == 5)
        #expect(report.allPassed, "\(report.results.compactMap(\.message))")
    }
}
