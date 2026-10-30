import Foundation
import IRIKit
import RDFCore
import RDFFormats
import RDFKit

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
/// is written in are the generated terms of ``TestManifest``, ``QueryTest``,
/// ``UpdateTest`` and ``SPARQLConformance``. As the manifest is read, each
/// entry's type IRI becomes the generated individual of the test class it
/// names, a ``SPARQLConformanceTest``, and each `sk:queryTemplate` node's type
/// becomes the ``SPARQLConformanceQueryTemplate`` it names.
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
        let graph = ManifestGraph(triples: try TurtleDecoder(base: base).decode(turtle))

        guard let manifest = graph.subjects(
            RDF.type.metadata.id,
            TestManifest.ManifestIndividual.metadata.id
        ).first else {
            throw SPARQLW3CManifestError.missingManifestNode
        }
        let name = graph.literal(manifest, TestManifest.name.metadata.id) ?? "W3C conformance subset"

        if let entries = graph.object(manifest, TestManifest.entries.metadata.id) {
            let cases = try graph.list(entries).map { entry in
                guard let node = entry.subject else {
                    throw SPARQLW3CManifestError.malformedEntry("An mf:entries item is not a node.")
                }
                return try SPARQLConformanceCase(manifestEntry: node, in: graph)
            }
            return SPARQLConformanceSuite(name: name, cases: cases)
        }

        if let includes = graph.object(manifest, TestManifest.include.metadata.id) {
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
    init(manifestEntry node: SubjectTerm, in graph: ManifestGraph) throws {
        let id = node.manifestIdentifier
        let test = try graph.test(of: node)
        let action = graph.object(node, TestManifest.action.metadata.id)?.subject

        func literals(_ predicate: IRI) -> [String] {
            graph.objects(node, predicate).compactMap(\.lexicalForm)
        }
        func iris(_ predicate: IRI) throws -> [IRI] {
            try literals(predicate).map { text in
                guard let iri = IRI(rawValue: text) else {
                    throw SPARQLW3CManifestError.malformedEntry("\(id): <\(text)> is not an absolute IRI.")
                }
                return iri
            }
        }
        func actionIRIs(_ predicate: IRI) -> [IRI] {
            action.map { graph.iris($0, predicate) } ?? []
        }
        func actionNamedGraphs(_ graphData: IRI, _ graphName: IRI) -> [IRI] {
            guard let action else { return [] }
            return graph.objects(action, graphData).flatMap { data -> [IRI] in
                switch data {
                case .iri(let iri): [iri]
                case .blankNode(let node): graph.iris(.blankNode(node), graphName)
                case .literal, .tripleTerm: []
                }
            }
        }

        let template = try graph.queryTemplate(of: node)
        self.init(
            id: id,
            test: test,
            fixtureFile: graph.fixtureFile(of: node, action: action),
            queryTemplate: template,
            queryText: graph.literal(node, SPARQLConformance.query.metadata.id),
            updateText: graph.literal(node, SPARQLConformance.update.metadata.id),
            defaultGraphs: try iris(SPARQLConformance.defaultGraphURI.metadata.id)
                + actionIRIs(QueryTest.data.metadata.id),
            namedGraphs: try iris(SPARQLConformance.namedGraphURI.metadata.id)
                + actionNamedGraphs(QueryTest.graphData.metadata.id, QueryTest.graph.metadata.id),
            usingGraphs: try iris(SPARQLConformance.usingGraphURI.metadata.id)
                + actionIRIs(UpdateTest.data.metadata.id),
            usingNamedGraphs: try iris(SPARQLConformance.usingNamedGraphURI.metadata.id)
                + actionNamedGraphs(UpdateTest.graphData.metadata.id, UpdateTest.graph.metadata.id),
            expectVariableCount: graph.literal(node, SPARQLConformance.expectVariableCount.metadata.id).flatMap { Int($0) },
            expectBindingCount: graph.literal(node, SPARQLConformance.expectBindingCount.metadata.id).flatMap { Int($0) },
            expectBoolean: graph.literal(node, SPARQLConformance.expectBoolean.metadata.id).flatMap { Bool($0.lowercased()) },
            expectContains: literals(SPARQLConformance.expectContains.metadata.id),
            expectURLContains: literals(SPARQLConformance.expectURLContains.metadata.id),
            expectBodyContains: literals(SPARQLConformance.expectBodyContains.metadata.id),
            expectHeaderContains: literals(SPARQLConformance.expectHeaderContains.metadata.id)
        )
    }
}

/// A decoded manifest, read by pattern.
struct ManifestGraph {
    let triples: Graph

    func subjects(_ predicate: IRI, _ object: IRI) -> [SubjectTerm] {
        triples.filter { $0.predicate == predicate && $0.object == .iri(object) }.map(\.subject)
    }

    func objects(_ subject: SubjectTerm, _ predicate: IRI) -> [ObjectTerm] {
        triples.filter { $0.subject == subject && $0.predicate == predicate }.map(\.object)
    }

    func object(_ subject: SubjectTerm, _ predicate: IRI) -> ObjectTerm? {
        triples.first { $0.subject == subject && $0.predicate == predicate }?.object
    }

    func iris(_ subject: SubjectTerm, _ predicate: IRI) -> [IRI] {
        objects(subject, predicate).compactMap { object in
            if case .iri(let iri) = object { return iri }
            return nil
        }
    }

    func literal(_ subject: SubjectTerm, _ predicate: IRI) -> String? {
        object(subject, predicate)?.lexicalForm
    }

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
            TestManifest.CSVResultFormatTestIndividual()
        ]
        for type in iris(node, RDF.type.metadata.id) {
            if let test = tests.individual(named: type) { return test }
        }
        throw SPARQLW3CManifestError.unsupportedTest(node.manifestIdentifier)
    }

    /// The typed query a render case names: the node its `sk:queryTemplate`
    /// points at is an individual of a template class.
    func queryTemplate(of node: SubjectTerm) throws -> (any SPARQLConformanceQueryTemplate)? {
        guard let object = object(node, SPARQLConformance.queryTemplate.metadata.id) else { return nil }
        let templates: [any SPARQLConformanceQueryTemplate] = [SPARQLConformance.BasicSelectQueryIndividual()]
        if let templateNode = object.subject {
            for type in iris(templateNode, RDF.type.metadata.id) {
                if let template = templates.individual(named: type) { return template }
            }
        }
        throw SPARQLW3CManifestError.malformedEntry(
            "\(node.manifestIdentifier): sk:queryTemplate names no query template SPARQLKit builds."
        )
    }

    /// The document a case reads: its `mf:result`, or the query or update its
    /// `mf:action` names.
    func fixtureFile(of node: SubjectTerm, action: SubjectTerm?) -> String? {
        if let result = iris(node, TestManifest.result.metadata.id).first {
            return result.manifestFileName
        }
        if case .iri(let document)? = object(node, TestManifest.action.metadata.id) {
            return document.manifestFileName
        }
        guard let action else { return nil }
        let document = iris(action, QueryTest.query.metadata.id).first
            ?? iris(action, UpdateTest.request.metadata.id).first
        return document?.manifestFileName
    }

    /// The members of an `rdf:first` / `rdf:rest` list.
    func list(_ head: ObjectTerm) throws -> [ObjectTerm] {
        var members: [ObjectTerm] = []
        var node = head
        while node != .iri(type(of: RDF.nil).metadata.id) {
            guard let cell = node.subject,
                  let first = object(cell, RDF.first.metadata.id),
                  let rest = object(cell, RDF.rest.metadata.id) else {
                throw SPARQLW3CManifestError.malformedEntry("Malformed RDF list: missing rdf:first or rdf:rest.")
            }
            members.append(first)
            node = rest
        }
        return members
    }
}

private extension ObjectTerm {
    var lexicalForm: String? {
        if case .literal(let literal) = self { return literal.lexicalForm }
        return nil
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
