import Foundation
import RDFCore
import Testing
@testable import SPARQLKit

@Suite("W3C manifests", .tags(.conformance))
struct SPARQLW3CManifestLoaderTests {
    @Test
    func w3cManifestLoaderBuildsSuiteAndRunnerExecutesCases() throws {
        let manifestData = try fixture("w3c_subset_manifest.ttl")
        let baseURL = URL(string: "https://example.org/manifests/w3c_subset_manifest.ttl")

        let suite = try SPARQLW3CManifestLoader().loadSuite(from: manifestData, baseURL: baseURL)

        #expect(suite.name == "SPARQLKit W3C subset")
        #expect(suite.cases.count == 11)

        let report = SPARQLConformanceRunner().run(suite: suite) { fileName in
            try fixture(fileName)
        }

        #expect(report.allPassed)
        #expect(report.failedCount == 0)
    }

    @Test
    func w3cManifestLoaderRejectsUnsupportedEntryOperation() throws {
        let turtle = """
        @prefix mf: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#> .

        <https://example.org/manifests/unsupported> a mf:Manifest ;
           mf:entries ( _:t ) .

        _:t mf:result <https://example.org/fixtures/select_result.json> .
        """

        do {
            _ = try SPARQLW3CManifestLoader().loadSuite(turtle: turtle)
            Issue.record("Expected unsupported operation error.")
        } catch let error as SPARQLW3CManifestError {
            if case .unsupportedTest = error {
                #expect(Bool(true))
            } else {
                Issue.record("Unexpected loader error: \(error)")
            }
        }
    }

    @Test
    func w3cManifestLoaderResolvesIncludedManifestsAndMergesCases() throws {
        let rootData = try fixture("w3c_subset_manifest_include_root.ttl")
        let baseURL = URL(string: "https://example.org/manifests/w3c_subset_manifest_include_root.ttl")

        let suite = try SPARQLW3CManifestLoader().loadSuite(
            from: rootData,
            baseURL: baseURL
        ) { includeFile in
            try fixture(includeFile)
        }

        #expect(suite.name == "SPARQLKit W3C include root")
        #expect(suite.cases.count == 4)

        let report = SPARQLConformanceRunner().run(suite: suite) { fileName in
            try fixture(fileName)
        }

        #expect(report.allPassed)
        #expect(report.failedCount == 0)
    }

    @Test
    func w3cManifestLoaderIncludeWithoutResolverFails() throws {
        let rootData = try fixture("w3c_subset_manifest_include_root.ttl")
        let baseURL = URL(string: "https://example.org/manifests/w3c_subset_manifest_include_root.ttl")

        do {
            _ = try SPARQLW3CManifestLoader().loadSuite(from: rootData, baseURL: baseURL)
            Issue.record("Expected missing include resolver error.")
        } catch let error as SPARQLW3CManifestError {
            #expect(error == .missingIncludeResolver)
        }
    }

    @Test
    func w3cManifestLoaderLoadsAggregatedSuiteFromIndex() throws {
        let indexData = try fixture("w3c_manifest_index.json")
        let baseURL = URL(string: "https://example.org/manifests/")

        let suite = try SPARQLW3CManifestLoader().loadSuite(
            fromIndexData: indexData,
            baseURL: baseURL
        ) { file in
            try fixture(file)
        }

        #expect(suite.name == "SPARQLKit aggregated W3C subset")
        #expect(suite.cases.count == 15)

        let report = SPARQLConformanceRunner().run(suite: suite) { fileName in
            try fixture(fileName)
        }
        #expect(report.allPassed)
    }

    @Test
    func w3cManifestLoaderLoadsExecutionPlanExpectedFailuresFromIndex() throws {
        let index = SPARQLW3CManifestIndex(
            name: "plan",
            manifests: ["w3c_subset_manifest.ttl"],
            expectedFailures: ["json-bindings-basic"]
        )

        let plan = try SPARQLW3CManifestLoader().loadPlan(
            fromIndex: index,
            baseURL: URL(string: "https://example.org/manifests/")
        ) { file in
            try fixture(file)
        }

        #expect(plan.suite.cases.count == 11)
        #expect(plan.expectedFailures == ["json-bindings-basic"])
    }

    @Test
    func w3cManifestLoaderDecodesIndexWithoutExpectedFailuresField() throws {
        let indexJSON = """
        {
          "name": "index-without-failures",
          "manifests": ["w3c_subset_manifest.ttl"]
        }
        """

        let indexData = Data(indexJSON.utf8)
        let index = try JSONDecoder().decode(SPARQLW3CManifestIndex.self, from: indexData)
        #expect(index.name == "index-without-failures")
        #expect(index.manifests.count == 1)
        #expect(index.expectedFailures.isEmpty)
    }

    @Test
    func w3cManifestLoaderMapsResultFormatTests() throws {
        let turtle = """
        @prefix mf: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#> .
        @prefix sk: <https://codex.local/sparqlkit/conformance#> .

        <https://example.org/manifests/mf-mapping> a mf:Manifest ;
           mf:entries ( <#csv> <#xml> <#json> ) .

        <#csv> a mf:CSVResultFormatTest ; mf:result <select_result_csv.csv> ;
          sk:expectVariableCount "2" ; sk:expectBindingCount "3" .
        <#xml> a sk:DecodeXMLBindingsTest ; mf:result <select_result_xml.xml> ;
          sk:expectVariableCount "2" ; sk:expectBindingCount "2" .
        <#json> a sk:DecodeJSONBindingsTest ; mf:result <select_result.json> ;
          sk:expectVariableCount "2" ; sk:expectBindingCount "3" .
        """

        let suite = try SPARQLW3CManifestLoader().loadSuite(
            turtle: turtle,
            baseURL: URL(string: "https://example.org/manifests/mf-mapping.ttl")
        )
        #expect(suite.cases.count == 3)
        #expect(suite.cases[0].test is TestManifest.CSVResultFormatTestIndividual)
        #expect(suite.cases[1].test is SPARQLConformance.DecodeXMLBindingsTestIndividual)
        #expect(suite.cases[2].test is SPARQLConformance.DecodeJSONBindingsTestIndividual)
    }

    @Test
    func w3cManifestLoaderMapsMfActionEvaluationTestsAndExecutesFixtures() throws {
        let turtle = """
        @prefix mf: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#> .
        @prefix sk: <https://codex.local/sparqlkit/conformance#> .

        <https://example.org/manifests/mf-action-mapping> a mf:Manifest ;
           mf:entries ( <#query-eval> <#update-eval> ) .

        <#query-eval> a mf:QueryEvaluationTest ; mf:action <query_eval.rq> ;
          sk:expectBodyContains "query=SELECT" .
        <#update-eval> a mf:UpdateEvaluationTest ; mf:action <update_eval.ru> ;
          sk:expectBodyContains "update=INSERT%20DATA" .
        """

        let suite = try SPARQLW3CManifestLoader().loadSuite(
            turtle: turtle,
            baseURL: URL(string: "https://example.org/manifests/mf-action-mapping.ttl")
        )
        #expect(suite.cases.count == 2)
        #expect(suite.cases[0].test is TestManifest.QueryEvaluationTestIndividual)
        #expect(suite.cases[1].test is TestManifest.UpdateEvaluationTestIndividual)

        let report = SPARQLConformanceRunner().run(suite: suite) { fileName in
            try fixture(fileName)
        }
        #expect(report.allPassed)
    }

    @Test
    func w3cManifestLoaderTakesTheResultKindOfAQueryEvaluationFromItsResultDocument() throws {
        let turtle = """
        @prefix mf: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#> .
        @prefix sk: <https://codex.local/sparqlkit/conformance#> .

        <https://example.org/manifests/mf-query-graph-inference> a mf:Manifest ;
           mf:entries ( <#query-eval-construct> <#query-eval-select> ) .

        <#query-eval-construct> a mf:QueryEvaluationTest ;
          mf:result <construct_result_turtle.ttl> ;
          sk:query "PREFIX ex: <http://example.org/> CONSTRUCT { ?s ex:p ?o } WHERE { ?s ex:p ?o }" ;
          sk:expectBodyContains "query=PREFIX" ;
          sk:expectHeaderContains "Accept:text/turtle" .

        <#query-eval-select> a mf:QueryEvaluationTest ;
          mf:result <select_result.srj> ;
          sk:query "CONSTRUCT { ?s ?p ?o } WHERE { ?s ?p ?o }" ;
          sk:expectHeaderContains "Accept:application/sparql-results+json" .
        """

        let suite = try SPARQLW3CManifestLoader().loadSuite(
            turtle: turtle,
            baseURL: URL(string: "https://example.org/manifests/mf-query-graph-inference.ttl")
        )
        #expect(suite.cases.count == 2)
        #expect(suite.cases[0].test is TestManifest.QueryEvaluationTestIndividual)
        #expect(suite.cases[1].test is TestManifest.QueryEvaluationTestIndividual)

        let report = SPARQLConformanceRunner().run(suite: suite) { fileName in
            try fixture(fileName)
        }
        #expect(report.allPassed)
    }

    @Test
    func w3cManifestLoaderParsesHeaderExpectationPredicates() throws {
        let turtle = """
        @prefix mf: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#> .
        @prefix sk: <https://codex.local/sparqlkit/conformance#> .

        <https://example.org/manifests/header-expect> a mf:Manifest ;
           mf:entries ( <#construct-case> ) .

        <#construct-case> a sk:ProtocolPostQueryRequestTest ;
          sk:query "SELECT * WHERE { ?s ?p ?o . }" ;
          sk:expectHeaderContains "Accept:application/sparql-results+json" .
        """

        let suite = try SPARQLW3CManifestLoader().loadSuite(
            turtle: turtle,
            baseURL: URL(string: "https://example.org/manifests/header-expect.ttl")
        )
        #expect(suite.cases.count == 1)
        #expect(suite.cases[0].expectHeaderContains == ["Accept:application/sparql-results+json"])

        let report = SPARQLConformanceRunner().run(suite: suite) { fileName in
            try fixture(fileName)
        }
        #expect(report.allPassed)
    }

    @Test
    func w3cManifestLoaderResolvesBlankNodeMfActionFixturesForQueryAndUpdate() throws {
        let turtle = """
        @prefix mf: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#> .
        @prefix qt: <http://www.w3.org/2001/sw/DataAccess/tests/test-query#> .
        @prefix ut: <http://www.w3.org/2009/sparql/tests/test-update#> .
        @prefix sk: <https://codex.local/sparqlkit/conformance#> .

        <https://example.org/manifests/mf-blank-action-mapping> a mf:Manifest ;
           mf:entries ( <#query-eval> <#update-eval> ) .

        <#query-eval> a mf:QueryEvaluationTest ;
          mf:action [ qt:query <query_eval.rq> ] ;
          sk:expectBodyContains "query=SELECT" .

        <#update-eval> a mf:UpdateEvaluationTest ;
          mf:action [ ut:request <update_eval.ru> ] ;
          sk:expectBodyContains "update=INSERT%20DATA" .
        """

        let suite = try SPARQLW3CManifestLoader().loadSuite(
            turtle: turtle,
            baseURL: URL(string: "https://example.org/manifests/mf-blank-action-mapping.ttl")
        )
        #expect(suite.cases.count == 2)
        #expect(suite.cases[0].fixtureFile == "query_eval.rq")
        #expect(suite.cases[1].fixtureFile == "update_eval.ru")
        #expect(suite.cases[0].test is TestManifest.QueryEvaluationTestIndividual)
        #expect(suite.cases[1].test is TestManifest.UpdateEvaluationTestIndividual)

        let report = SPARQLConformanceRunner().run(suite: suite) { fileName in
            try fixture(fileName)
        }
        #expect(report.allPassed)
    }

    @Test
    func w3cManifestLoaderInfersQueryDatasetsFromBlankNodeAction() throws {
        let turtle = """
        @prefix mf: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#> .
        @prefix qt: <http://www.w3.org/2001/sw/DataAccess/tests/test-query#> .
        @prefix sk: <https://codex.local/sparqlkit/conformance#> .

        <https://example.org/manifests/mf-query-action-dataset> a mf:Manifest ;
           mf:entries ( <#query-eval> ) .

        <#query-eval> a mf:QueryEvaluationTest ;
          mf:action [
            qt:query <query_eval.rq> ;
            qt:data <https://example.org/graphs/default> ;
            qt:graphData [ qt:graph <https://example.org/graphs/named> ]
          ] ;
          sk:expectBodyContains "default-graph-uri=https%3A%2F%2Fexample.org%2Fgraphs%2Fdefault" ,
                                "named-graph-uri=https%3A%2F%2Fexample.org%2Fgraphs%2Fnamed" .
        """

        let suite = try SPARQLW3CManifestLoader().loadSuite(
            turtle: turtle,
            baseURL: URL(string: "https://example.org/manifests/mf-query-action-dataset.ttl")
        )
        #expect(suite.cases.count == 1)
        let single = try #require(suite.cases.first)
        #expect(single.fixtureFile == "query_eval.rq")
        #expect(single.defaultGraphs == ["https://example.org/graphs/default"])
        #expect(single.namedGraphs == ["https://example.org/graphs/named"])

        let report = SPARQLConformanceRunner().run(suite: suite) { fileName in
            try fixture(fileName)
        }
        #expect(report.allPassed)
    }

    @Test
    func w3cManifestLoaderInfersUpdateDatasetsFromBlankNodeAction() throws {
        let turtle = """
        @prefix mf: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#> .
        @prefix ut: <http://www.w3.org/2009/sparql/tests/test-update#> .
        @prefix sk: <https://codex.local/sparqlkit/conformance#> .

        <https://example.org/manifests/mf-update-action-dataset> a mf:Manifest ;
           mf:entries ( <#update-eval> ) .

        <#update-eval> a mf:UpdateEvaluationTest ;
          mf:action [
            ut:request <update_eval.ru> ;
            ut:data <https://example.org/graphs/u-default> ;
            ut:graphData [ ut:graph <https://example.org/graphs/u-named> ]
          ] ;
          sk:expectBodyContains "using-graph-uri=https%3A%2F%2Fexample.org%2Fgraphs%2Fu-default" ,
                                "using-named-graph-uri=https%3A%2F%2Fexample.org%2Fgraphs%2Fu-named" .
        """

        let suite = try SPARQLW3CManifestLoader().loadSuite(
            turtle: turtle,
            baseURL: URL(string: "https://example.org/manifests/mf-update-action-dataset.ttl")
        )
        #expect(suite.cases.count == 1)
        let single = try #require(suite.cases.first)
        #expect(single.fixtureFile == "update_eval.ru")
        #expect(single.usingGraphs == ["https://example.org/graphs/u-default"])
        #expect(single.usingNamedGraphs == ["https://example.org/graphs/u-named"])

        let report = SPARQLConformanceRunner().run(suite: suite) { fileName in
            try fixture(fileName)
        }
        #expect(report.allPassed)
    }

    @Test
    func w3cManifestLoaderMapsGraphStoreRequestTestTypes() throws {
        let turtle = """
        @prefix mf: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#> .
        @prefix sk: <https://codex.local/sparqlkit/conformance#> .

        <https://example.org/manifests/gsp-mapping> a mf:Manifest ;
           mf:entries ( <#get-default> <#head-named> <#post-service> <#put-named> <#delete-named> ) .

        <#get-default> a sk:GraphStoreGetDefaultRequestTest ;
          sk:expectURLContains "default" .
        <#head-named> a sk:GraphStoreHeadNamedRequestTest ;
          sk:namedGraphURI "https://example.org/graphs/named" ;
          sk:expectURLContains "graph=https%3A%2F%2Fexample.org%2Fgraphs%2Fnamed" .
        <#post-service> a sk:GraphStorePostServiceRequestTest ;
          sk:expectBodyContains "<http://example.org/s> <http://example.org/p> <http://example.org/o> ." .
        <#put-named> a sk:GraphStorePutNamedRequestTest ;
          sk:namedGraphURI "https://example.org/graphs/named-put" ;
          sk:expectURLContains "graph=https%3A%2F%2Fexample.org%2Fgraphs%2Fnamed-put" ;
          sk:expectBodyContains "<http://example.org/s> <http://example.org/p> <http://example.org/o> ." .
        <#delete-named> a sk:GraphStoreDeleteNamedRequestTest ;
          sk:namedGraphURI "https://example.org/graphs/named-delete" ;
          sk:expectURLContains "graph=https%3A%2F%2Fexample.org%2Fgraphs%2Fnamed-delete" .
        """

        let suite = try SPARQLW3CManifestLoader().loadSuite(
            turtle: turtle,
            baseURL: URL(string: "https://example.org/manifests/gsp-mapping.ttl")
        )
        #expect(suite.cases.count == 5)
        #expect(suite.cases[0].test is SPARQLConformance.GraphStoreGetDefaultRequestTestIndividual)
        #expect(suite.cases[1].test is SPARQLConformance.GraphStoreHeadNamedRequestTestIndividual)
        #expect(suite.cases[2].test is SPARQLConformance.GraphStorePostServiceRequestTestIndividual)
        #expect(suite.cases[3].test is SPARQLConformance.GraphStorePutNamedRequestTestIndividual)
        #expect(suite.cases[4].test is SPARQLConformance.GraphStoreDeleteNamedRequestTestIndividual)

        let report = SPARQLConformanceRunner().run(suite: suite) { fileName in
            try fixture(fileName)
        }
        #expect(report.allPassed)
    }

    @Test("Every test class the vocabularies declare decodes into a test SPARQLKit runs", .tags(.vocabulary))
    func everyDeclaredTestClassIsRunnable() throws {
        // The test classes SPARQLConformance and TestManifest declare: the
        // loader must know each of them, so the vocabulary and the loader
        // cannot drift.
        let classes = SPARQLConformance().entities.compactMap { ($0 as? RDFCore.Class)?.localName }
            .filter { $0.hasSuffix("Test") }
            .map { ("sk", $0) }
            + TestManifest().entities.compactMap { ($0 as? RDFCore.Class)?.localName }
            .filter { $0.hasSuffix("Test") }
            .map { ("mf", $0) }
        let entries = classes.map { "<#\($0.1)>" }.joined(separator: " ")
        let types = classes.map { "<#\($0.1)> a \($0.0):\($0.1) ." }.joined(separator: "\n")
        let turtle = """
        @prefix mf: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#> .
        @prefix sk: <https://codex.local/sparqlkit/conformance#> .

        <https://example.org/manifests/every-class> a mf:Manifest ;
           mf:entries ( \(entries) ) .
        \(types)
        """

        let suite = try SPARQLW3CManifestLoader().loadSuite(turtle: turtle, baseURL: URL(string: "https://example.org/manifests/m.ttl"))

        #expect(classes.count == 20)
        #expect(suite.cases.map { type(of: $0.test as any RDFCore.Entity).metadata.name } == classes.map(\.1))
    }

    @Test("A render case names its query by the class of its sk:queryTemplate node")
    func renderCaseDecodesItsTemplate() throws {
        let turtle = """
        @prefix mf: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#> .
        @prefix sk: <https://codex.local/sparqlkit/conformance#> .

        <https://example.org/manifests/render> a mf:Manifest ;
           mf:entries ( <#render> ) .
        <#render> a sk:RenderQueryTest ;
          sk:queryTemplate [ a sk:BasicSelectQuery ] ;
          sk:expectContains "SELECT ?s ?o" .
        """

        let suite = try SPARQLW3CManifestLoader().loadSuite(turtle: turtle, baseURL: URL(string: "https://example.org/manifests/m.ttl"))

        #expect(suite.cases.first?.test is SPARQLConformance.RenderQueryTestIndividual)
        #expect(suite.cases.first?.queryTemplate is SPARQLConformance.BasicSelectQueryIndividual)
        #expect(SPARQLConformanceRunner().run(suite: suite, loadFixture: fixture).allPassed)
    }

    @Test(
        "A query template named by a string or an unknown class is rejected",
        arguments: [#""basicSelect""#, "[ a sk:UnknownQuery ]", "sk:BasicSelectQuery"]
    )
    func templateByStringIsRejected(template: String) {
        let turtle = """
        @prefix mf: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#> .
        @prefix sk: <https://codex.local/sparqlkit/conformance#> .

        <https://example.org/manifests/render> a mf:Manifest ;
           mf:entries ( <#render> ) .
        <#render> a sk:RenderQueryTest ;
          sk:queryTemplate \(template) .
        """

        #expect(throws: SPARQLW3CManifestError.self) {
            _ = try SPARQLW3CManifestLoader().loadSuite(turtle: turtle, baseURL: URL(string: "https://example.org/manifests/m.ttl"))
        }
    }

    @Test("A render case without a template fails when it runs")
    func renderCaseWithoutTemplateFails() {
        let suite = SPARQLConformanceSuite(name: "render", cases: [
            SPARQLConformanceCase(id: "no-template", test: SPARQLConformance.RenderQueryTestIndividual())
        ])
        let report = SPARQLConformanceRunner().run(suite: suite, loadFixture: fixture)

        #expect(report.failedCount == 1)
        #expect(report.results.first?.message == String(describing: SPARQLConformanceError.missingQueryTemplate("no-template")))
    }
}
