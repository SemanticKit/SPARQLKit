import Foundation
import IRIKit
import RDFCore
import RDF
import RDFFormats
import SPARQLConformance
import TestManifest
import TestQuery
import TestUpdate

public enum SPARQLW3CManifestError: Error, Equatable, Sendable {
    case missingManifestNode
    case missingEntries
    case malformedEntry(String)
    case unsupportedTest(String)
    case missingIncludeResolver
}

/// Reads W3C test manifests into a ``SPARQLConformanceSuite``.
///
/// A manifest is Turtle, read by RDFFormats' ``TurtleDecoder``. The terms it
/// is written in are the translated vocabularies `TestManifest`, `TestQuery`,
/// `TestUpdate` and `SPARQLConformance`, and the manifest's triples are
/// matched by their translated properties. As the manifest is read, each
/// entry's type IRI becomes the generated class of the test it names, a
/// ``SPARQLConformanceTest``, and each `sk:queryTemplate` node's type becomes
/// the ``SPARQLConformanceQueryTemplate`` it names.
public struct SPARQLW3CManifestLoader {
    public init() {}

    public func loadSuite(
        from data: Data,
        baseURL: URL?,
        loadIncludedManifest: ((String) throws -> Data)? = nil
    ) throws -> SPARQLConformanceSuite {
        guard let turtle = String(data: data, encoding: .utf8) else {
            throw SPARQLConformanceError.assertionFailed("Manifest is not UTF-8 Turtle.")
        }
        return try loadSuite(turtle: turtle, baseURL: baseURL, loadIncludedManifest: loadIncludedManifest)
    }

    public func loadSuite(
        turtle: String,
        baseURL: URL? = nil,
        loadIncludedManifest: ((String) throws -> Data)? = nil
    ) throws -> SPARQLConformanceSuite {
        let base = baseURL.flatMap { IRI(rawValue: $0.absoluteString) }
        let graph = try TurtleDecoder(base: base).decode(turtle)

        guard let manifest = graph.members(of: TestManifest.ManifestIndividual.self).first else {
            throw SPARQLW3CManifestError.missingManifestNode
        }
        let name = graph.lexicalForms(TestManifest.name, of: manifest).first ?? "W3C conformance subset"

        if let entries = graph.object(TestManifest.entries, of: manifest) {
            let cases = try graph.list(entries).map { entry in
                guard let node = entry.subject else {
                    throw SPARQLW3CManifestError.malformedEntry("An mf:entries item is not a node.")
                }
                return try SPARQLConformanceCase(manifestEntry: node, in: graph)
            }
            return SPARQLConformanceSuite(name: name, cases: cases)
        }

        if let includes = graph.object(TestManifest.include, of: manifest) {
            guard let loadIncludedManifest else {
                throw SPARQLW3CManifestError.missingIncludeResolver
            }
            var cases: [SPARQLConformanceCase] = []
            for include in try graph.list(includes) {
                guard case .iri(let included) = include else {
                    throw SPARQLW3CManifestError.malformedEntry("mf:include list item must be an IRI.")
                }
                let child = try loadSuite(
                    from: try loadIncludedManifest(included.manifestFileName),
                    baseURL: URL(string: included.rawValue),
                    loadIncludedManifest: loadIncludedManifest
                )
                cases += child.cases
            }
            return SPARQLConformanceSuite(name: name, cases: cases)
        }

        throw SPARQLW3CManifestError.missingEntries
    }
}

extension SPARQLConformanceCase {
    /// The case an `mf:entries` item of a manifest describes.
    init(manifestEntry node: SubjectTerm, in graph: RDFCore.Graph) throws {
        let id = node.manifestIdentifier
        let test = try graph.test(of: node)
        let action = graph.object(TestManifest.action, of: node)?.subject

        func iris(_ property: any RDFCore.Resource) throws -> [IRI] {
            try graph.lexicalForms(property, of: node).map { text in
                guard let iri = IRI(rawValue: text) else {
                    throw SPARQLW3CManifestError.malformedEntry("\(id): <\(text)> is not an absolute IRI.")
                }
                return iri
            }
        }
        func actionIRIs(_ property: any RDFCore.Resource) -> [IRI] {
            action.map { graph.iris(property, of: $0) } ?? []
        }
        // `ut:graphData` names a named graph's document directly, or through
        // the `ut:graph` of a node that also labels it (test-update.ttl).
        func actionUpdateNamedGraphs() -> [IRI] {
            guard let action else { return [] }
            return graph.objects(TestUpdate.graphData, of: action).flatMap { data -> [IRI] in
                switch data {
                case .iri(let iri): [iri]
                case .blankNode(let node): graph.iris(TestUpdate.graph, of: .blankNode(node))
                case .literal, .tripleTerm: []
                }
            }
        }
        func literal(_ property: any RDFCore.Resource) -> String? {
            graph.lexicalForms(property, of: node).first
        }

        let template = try graph.queryTemplate(of: node)
        self.init(
            id: id,
            test: test,
            fixtureFile: graph.fixtureFile(of: node, action: action),
            queryTemplate: template,
            queryText: literal(SPARQLConformance.query),
            updateText: literal(SPARQLConformance.update),
            defaultGraphs: try iris(SPARQLConformance.defaultGraphURI) + actionIRIs(TestQuery.data),
            namedGraphs: try iris(SPARQLConformance.namedGraphURI) + actionIRIs(TestQuery.graphData),
            usingGraphs: try iris(SPARQLConformance.usingGraphURI) + actionIRIs(TestUpdate.data),
            usingNamedGraphs: try iris(SPARQLConformance.usingNamedGraphURI) + actionUpdateNamedGraphs(),
            expectVariableCount: literal(SPARQLConformance.expectVariableCount).flatMap { Int($0) },
            expectBindingCount: literal(SPARQLConformance.expectBindingCount).flatMap { Int($0) },
            expectBoolean: literal(SPARQLConformance.expectBoolean).flatMap { Bool($0.lowercased()) },
            expectContains: graph.lexicalForms(SPARQLConformance.expectContains, of: node),
            expectURLContains: graph.lexicalForms(SPARQLConformance.expectURLContains, of: node),
            expectBodyContains: graph.lexicalForms(SPARQLConformance.expectBodyContains, of: node),
            expectHeaderContains: graph.lexicalForms(SPARQLConformance.expectHeaderContains, of: node)
        )
    }
}

/// A decoded manifest, read by its translated vocabularies.
extension RDFCore.Graph {
    /// The test a manifest entry is: the generated individual of the first
    /// test class its `rdf:type` names that SPARQLKit runs.
    func test(of node: SubjectTerm) throws -> any SPARQLConformanceTest {
        let tests: [any SPARQLConformanceTest] = [
            SPARQLConformance.DecodeJSONBindingsTestIndividual(), SPARQLConformance.DecodeJSONBooleanTestIndividual(),
            SPARQLConformance.DecodeXMLBindingsTestIndividual(), SPARQLConformance.DecodeXMLBooleanTestIndividual(),
            SPARQLConformance.DecodeCSVBindingsTestIndividual(), SPARQLConformance.DecodeTSVBindingsTestIndividual(),
            SPARQLConformance.RenderQueryTestIndividual(),
            SPARQLConformance.ProtocolGetQueryRequestTestIndividual(), SPARQLConformance.ProtocolPostQueryRequestTestIndividual(),
            SPARQLConformance.ProtocolGetGraphQueryRequestTestIndividual(),
            SPARQLConformance.ProtocolPostGraphQueryRequestTestIndividual(),
            SPARQLConformance.ProtocolPostUpdateRequestTestIndividual(),
            SPARQLConformance.GraphStoreGetDefaultRequestTestIndividual(),
            SPARQLConformance.GraphStoreHeadNamedRequestTestIndividual(),
            SPARQLConformance.GraphStorePostServiceRequestTestIndividual(),
            SPARQLConformance.GraphStorePutNamedRequestTestIndividual(),
            SPARQLConformance.GraphStoreDeleteNamedRequestTestIndividual(),
            TestManifest.QueryEvaluationTestIndividual(), TestManifest.UpdateEvaluationTestIndividual(),
            SPARQLConformance.CSVResultFormatTestIndividual()
        ]
        for type in iris(RDF.type, of: node) {
            if let test = tests.member(ofClassDenotedBy: type) { return test }
        }
        throw SPARQLW3CManifestError.unsupportedTest(node.manifestIdentifier)
    }

    /// The typed query a render case names: the node its `sk:queryTemplate`
    /// points at is an individual of a template class.
    func queryTemplate(of node: SubjectTerm) throws -> (any SPARQLConformanceQueryTemplate)? {
        guard let object = object(SPARQLConformance.queryTemplate, of: node) else { return nil }
        let templates: [any SPARQLConformanceQueryTemplate] = [SPARQLConformance.BasicSelectQueryIndividual()]
        if let templateNode = object.subject {
            for type in iris(RDF.type, of: templateNode) {
                if let template = templates.member(ofClassDenotedBy: type) { return template }
            }
        }
        throw SPARQLW3CManifestError.malformedEntry(
            "\(node.manifestIdentifier): sk:queryTemplate names no query template SPARQLKit builds."
        )
    }

    /// The document a case reads: its `mf:result`, or the query or update its
    /// `mf:action` names.
    func fixtureFile(of node: SubjectTerm, action: SubjectTerm?) -> String? {
        if let result = iris(TestManifest.result, of: node).first {
            return result.manifestFileName
        }
        if case .iri(let document)? = object(TestManifest.action, of: node) {
            return document.manifestFileName
        }
        guard let action else { return nil }
        let document = iris(TestQuery.query, of: action).first ?? iris(TestUpdate.request, of: action).first
        return document?.manifestFileName
    }

    /// The members of an `rdf:first` / `rdf:rest` list.
    func list(_ head: ObjectTerm) throws -> [ObjectTerm] {
        var members: [ObjectTerm] = []
        var node = head
        while node.subject.flatMap(\.iri) != RDF.nil.iri {
            guard let cell = node.subject,
                  let first = object(RDF.first, of: cell),
                  let rest = object(RDF.rest, of: cell) else {
                throw SPARQLW3CManifestError.malformedEntry("Malformed RDF list: missing rdf:first or rdf:rest.")
            }
            members.append(first)
            node = rest
        }
        return members
    }
}

private extension IRI {
    /// The file a manifest IRI names: its last path component.
    var manifestFileName: String {
        URL(string: rawValue)?.lastPathComponent ?? rawValue
    }
}

private extension SubjectTerm {
    /// The name a manifest entry is reported by: its IRI's fragment or file
    /// name, or its blank node label.
    var manifestIdentifier: String {
        switch self {
        case .iri(let iri):
            if let fragment = URL(string: iri.rawValue)?.fragment { return fragment }
            return iri.manifestFileName
        case .blankNode(let blank):
            return blank.identifier
        }
    }
}
