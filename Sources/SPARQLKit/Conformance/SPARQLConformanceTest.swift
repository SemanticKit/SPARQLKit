import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import RDFCore
import SPARQLConformance
import TestManifest

/// A kind of conformance test SPARQLKit runs.
///
/// A manifest entry is an individual of a test class: `sk:DecodeJSONBindingsTest`,
/// `mf:QueryEvaluationTest` and the others that the translated
/// `SPARQLConformance` and `TestManifest` vocabularies declare. Each class's
/// generated Swift class conforms here, so what a test of that class does is
/// behaviour on the type, and the entry's `rdf:type` is all that says which
/// test runs.
public protocol SPARQLConformanceTest: RDFCore.ResourceClass, Sendable {
    /// Runs one case of this test, throwing when the case's expectations do
    /// not hold.
    func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws
}

extension SPARQLConformance.DecodeJSONBindingsTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        let result: SPARQLResultSet = try SPARQLJSONResultDecoder().decode(try testCase.fixtureData(loadFixture))
        try testCase.expectBindings(result)
    }
}

extension SPARQLConformance.DecodeJSONBooleanTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        let result: SPARQLQueryResult = try SPARQLJSONResultDecoder().decode(try testCase.fixtureData(loadFixture))
        try testCase.expectBoolean(result)
    }
}

extension SPARQLConformance.DecodeXMLBindingsTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        let result: SPARQLResultSet = try SPARQLXMLResultDecoder().decode(try testCase.fixtureData(loadFixture))
        try testCase.expectBindings(result)
    }
}

extension SPARQLConformance.DecodeXMLBooleanTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        let result: SPARQLQueryResult = try SPARQLXMLResultDecoder().decode(try testCase.fixtureData(loadFixture))
        try testCase.expectBoolean(result)
    }
}

extension SPARQLConformance.DecodeCSVBindingsTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        try testCase.expectBindings(try SPARQLCSVResultDecoder().decode(try testCase.fixtureData(loadFixture)))
    }
}

/// `mf:CSVResultFormatTest`: a CSV results document (SPARQL 1.2 Query
/// Results CSV and TSV Formats test suite).
extension SPARQLConformance.CSVResultFormatTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        try testCase.expectBindings(try SPARQLCSVResultDecoder().decode(try testCase.fixtureData(loadFixture)))
    }
}

extension SPARQLConformance.DecodeTSVBindingsTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        try testCase.expectBindings(try SPARQLTSVResultDecoder().decode(try testCase.fixtureData(loadFixture)))
    }
}

extension SPARQLConformance.RenderQueryTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        guard let template = testCase.queryTemplate else {
            throw SPARQLConformanceError.missingQueryTemplate(testCase.id)
        }
        try testCase.expectRendered(template.query.render())
    }
}

extension SPARQLConformance.ProtocolGetQueryRequestTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        let request = try testCase.endpointClient.makeQueryRequest(
            try testCase.query(loadFixture),
            accept: SPARQLAccept.jsonResults.rawValue,
            method: .get,
            options: testCase.queryOptions
        )
        try testCase.expectRequest(request, method: "GET")
    }
}

extension SPARQLConformance.ProtocolPostQueryRequestTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        let request = try testCase.endpointClient.makeQueryRequest(
            try testCase.query(loadFixture),
            accept: SPARQLAccept.jsonResults.rawValue,
            method: .post,
            options: testCase.queryOptions
        )
        try testCase.expectRequest(request, method: "POST")
    }
}

extension SPARQLConformance.ProtocolGetGraphQueryRequestTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        let request = try testCase.endpointClient.makeQueryRequest(
            try testCase.query(loadFixture),
            accept: SPARQLGraphAccept.turtle.rawValue,
            method: .get,
            options: testCase.queryOptions
        )
        try testCase.expectRequest(request, method: "GET")
    }
}

extension SPARQLConformance.ProtocolPostGraphQueryRequestTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        let request = try testCase.endpointClient.makeQueryRequest(
            try testCase.query(loadFixture),
            accept: SPARQLGraphAccept.turtle.rawValue,
            method: .post,
            options: testCase.queryOptions
        )
        try testCase.expectRequest(request, method: "POST")
    }
}

/// `mf:QueryEvaluationTest`: the query is sent with POST. What it returns is
/// what its `mf:result` document holds: the W3C SPARQL test suites name each
/// result document with the extension of its format, so an RDF document
/// (Turtle, N-Triples, RDF/XML, JSON-LD) means a graph, sent for as Turtle,
/// and a results document (`.srj`, `.srx`, `.csv`, `.tsv`) means solutions.
/// The manifest, not the query text, says what the query returns.
extension TestManifest.QueryEvaluationTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        let resultExtension = testCase.fixtureFile.map { URL(fileURLWithPath: $0).pathExtension.lowercased() }
        let returnsGraph = resultExtension.map(["ttl", "nt", "rdf", "jsonld"].contains) ?? false
        let request = try testCase.endpointClient.makeQueryRequest(
            try testCase.query(loadFixture),
            accept: returnsGraph ? SPARQLGraphAccept.turtle.rawValue : SPARQLAccept.jsonResults.rawValue,
            method: .post,
            options: testCase.queryOptions
        )
        try testCase.expectRequest(request, method: "POST")
    }
}

extension SPARQLConformance.ProtocolPostUpdateRequestTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        let request = try testCase.endpointClient.makeUpdateRequest(
            try testCase.update(loadFixture),
            options: SPARQLUpdateRequestOptions(usingGraphs: testCase.usingGraphs, usingNamedGraphs: testCase.usingNamedGraphs)
        )
        try testCase.expectRequest(request, method: "POST")
    }
}

/// `mf:UpdateEvaluationTest`: the update is sent with POST.
extension TestManifest.UpdateEvaluationTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        let request = try testCase.endpointClient.makeUpdateRequest(
            try testCase.update(loadFixture),
            options: SPARQLUpdateRequestOptions(usingGraphs: testCase.usingGraphs, usingNamedGraphs: testCase.usingNamedGraphs)
        )
        try testCase.expectRequest(request, method: "POST")
    }
}

extension SPARQLConformance.GraphStoreGetDefaultRequestTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        let request = try testCase.graphStoreClient.makeRequest(
            method: "GET",
            graph: .defaultGraph,
            accept: SPARQLGraphAccept.turtle.rawValue
        )
        try testCase.expectRequest(request, method: "GET")
    }
}

extension SPARQLConformance.GraphStoreHeadNamedRequestTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        let request = try testCase.graphStoreClient.makeRequest(method: "HEAD", graph: .named(try testCase.namedGraph()))
        try testCase.expectRequest(request, method: "HEAD")
    }
}

extension SPARQLConformance.GraphStorePostServiceRequestTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        let request = try testCase.graphStoreClient.makeRequest(
            method: "POST",
            graph: .service,
            contentType: SPARQLGraphAccept.ntriples.rawValue,
            body: testCase.graphStoreBody
        )
        try testCase.expectRequest(request, method: "POST")
    }
}

extension SPARQLConformance.GraphStorePutNamedRequestTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        let request = try testCase.graphStoreClient.makeRequest(
            method: "PUT",
            graph: .named(try testCase.namedGraph()),
            contentType: SPARQLGraphAccept.ntriples.rawValue,
            body: testCase.graphStoreBody
        )
        try testCase.expectRequest(request, method: "PUT")
    }
}

extension SPARQLConformance.GraphStoreDeleteNamedRequestTestIndividual: SPARQLConformanceTest {
    public func run(_ testCase: SPARQLConformanceCase, loadFixture: (String) throws -> Data) throws {
        let request = try testCase.graphStoreClient.makeRequest(method: "DELETE", graph: .named(try testCase.namedGraph()))
        try testCase.expectRequest(request, method: "DELETE")
    }
}
