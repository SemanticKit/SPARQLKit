import Foundation
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
            if case .unsupportedOperation = error {
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
        let index = try SPARQLW3CManifestIndex.decode(from: indexData)
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
        #expect(suite.cases[0].operation == .decodeCSVBindings)
        #expect(suite.cases[1].operation == .decodeXMLBindings)
        #expect(suite.cases[2].operation == .decodeJSONBindings)
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
        #expect(suite.cases[0].operation == .buildPOSTQueryRequest)
        #expect(suite.cases[1].operation == .buildPOSTUpdateRequest)

        let report = SPARQLConformanceRunner().run(suite: suite) { fileName in
            try fixture(fileName)
        }
        #expect(report.allPassed)
    }

    @Test
    func w3cManifestLoaderInfersGraphQueryOperationForMfQueryEvaluationWithConstructQuery() throws {
        let turtle = """
        @prefix mf: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#> .
        @prefix sk: <https://codex.local/sparqlkit/conformance#> .

        <https://example.org/manifests/mf-query-graph-inference> a mf:Manifest ;
           mf:entries ( <#query-eval-construct> ) .

        <#query-eval-construct> a mf:QueryEvaluationTest ;
          sk:query "CONSTRUCT { ?s ?p ?o . } WHERE { ?s ?p ?o . }" ;
          sk:expectBodyContains "query=CONSTRUCT" .
        """

        let suite = try SPARQLW3CManifestLoader().loadSuite(
            turtle: turtle,
            baseURL: URL(string: "https://example.org/manifests/mf-query-graph-inference.ttl")
        )
        #expect(suite.cases.count == 1)
        #expect(suite.cases[0].operation == .buildPOSTGraphQueryRequest)

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
          sk:query "CONSTRUCT { ?s ?p ?o . } WHERE { ?s ?p ?o . }" ;
          sk:expectHeaderContains "Accept:text/turtle" .
        """

        let suite = try SPARQLW3CManifestLoader().loadSuite(
            turtle: turtle,
            baseURL: URL(string: "https://example.org/manifests/header-expect.ttl")
        )
        #expect(suite.cases.count == 1)
        #expect(suite.cases[0].expectHeaderContains == ["Accept:text/turtle"])

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
        #expect(suite.cases[0].operation == .buildPOSTQueryRequest)
        #expect(suite.cases[1].operation == .buildPOSTUpdateRequest)

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
          sk:expectURLContains "graph=https://example.org/graphs/named" .
        <#post-service> a sk:GraphStorePostServiceRequestTest ;
          sk:expectBodyContains "<http://example.org/s> <http://example.org/p> <http://example.org/o> ." .
        <#put-named> a sk:GraphStorePutNamedRequestTest ;
          sk:namedGraphURI "https://example.org/graphs/named-put" ;
          sk:expectURLContains "graph=https://example.org/graphs/named-put" ;
          sk:expectBodyContains "<http://example.org/s> <http://example.org/p> <http://example.org/o> ." .
        <#delete-named> a sk:GraphStoreDeleteNamedRequestTest ;
          sk:namedGraphURI "https://example.org/graphs/named-delete" ;
          sk:expectURLContains "graph=https://example.org/graphs/named-delete" .
        """

        let suite = try SPARQLW3CManifestLoader().loadSuite(
            turtle: turtle,
            baseURL: URL(string: "https://example.org/manifests/gsp-mapping.ttl")
        )
        #expect(suite.cases.count == 5)
        #expect(suite.cases[0].operation == .buildGETDefaultGraphStoreRequest)
        #expect(suite.cases[1].operation == .buildHEADNamedGraphStoreRequest)
        #expect(suite.cases[2].operation == .buildPOSTServiceGraphStoreRequest)
        #expect(suite.cases[3].operation == .buildPUTNamedGraphStoreRequest)
        #expect(suite.cases[4].operation == .buildDELETENamedGraphStoreRequest)

        let report = SPARQLConformanceRunner().run(suite: suite) { fileName in
            try fixture(fileName)
        }
        #expect(report.allPassed)
    }
}
