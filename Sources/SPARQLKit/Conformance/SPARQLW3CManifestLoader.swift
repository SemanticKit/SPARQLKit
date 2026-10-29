import Foundation
import IRIKit
import RDFCore
import RDFFormats
import RDFKit

public enum SPARQLW3CManifestError: Error, Equatable, Sendable {
    case missingManifestNode
    case missingEntries
    case malformedEntry(String)
    case unsupportedOperation(String)
    case missingIncludeResolver
}

/// Reads W3C test manifests into a ``SPARQLConformanceSuite``.
///
/// A manifest is Turtle, read by RDFFormats' ``TurtleDecoder``. The terms it
/// is written in are the generated terms of ``TestManifest``, ``QueryTest``,
/// ``UpdateTest`` and ``SPARQLConformance``; each test's type IRI becomes the
/// operation it names as the manifest is read.
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
            RDF.type<any RDFCore.Resource>.metadata.id,
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
                return try parseCase(node, in: graph)
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
                    from: try loadIncludedManifest(fileName(of: included)),
                    baseURL: URL(string: included.rawValue),
                    loadIncludedManifest: loadIncludedManifest
                )
                cases += child.cases
            }
            return SPARQLConformanceSuite(name: name, cases: cases)
        }

        throw SPARQLW3CManifestError.missingEntries
    }

    private func parseCase(_ node: SubjectTerm, in graph: ManifestGraph) throws -> SPARQLConformanceCase {
        let id = identifier(of: node)
        let operation = try parseOperation(node, in: graph)
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

        let template = graph.literal(node, SPARQLConformance.queryTemplate.metadata.id)
            .flatMap(SPARQLConformanceQueryTemplate.init(rawValue:))
        if operation == .renderQuery, template == nil {
            throw SPARQLW3CManifestError.malformedEntry("\(id): render query case missing sk:queryTemplate")
        }

        return SPARQLConformanceCase(
            id: id,
            operation: operation,
            fixtureFile: fixtureFile(of: node, action: action, in: graph),
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

    /// The operation a case's `sk:operation` or type names.
    private func parseOperation(_ node: SubjectTerm, in graph: ManifestGraph) throws -> SPARQLConformanceOperation {
        if let explicit = graph.literal(node, SPARQLConformance.operation.metadata.id),
           let operation = SPARQLConformanceOperation(rawValue: explicit) {
            return operation
        }
        for type in graph.iris(node, RDF.type<any RDFCore.Resource>.metadata.id) {
            if let operation = operation(ofType: type, node: node, in: graph) {
                return operation
            }
        }
        throw SPARQLW3CManifestError.unsupportedOperation(identifier(of: node))
    }

    private func operation(ofType type: IRI, node: SubjectTerm, in graph: ManifestGraph) -> SPARQLConformanceOperation? {
        switch type {
        case SPARQLConformance.DecodeJSONBindingsTestIndividual.metadata.id: .decodeJSONBindings
        case SPARQLConformance.DecodeJSONBooleanTestIndividual.metadata.id: .decodeJSONBoolean
        case SPARQLConformance.DecodeXMLBindingsTestIndividual.metadata.id: .decodeXMLBindings
        case SPARQLConformance.DecodeXMLBooleanTestIndividual.metadata.id: .decodeXMLBoolean
        case SPARQLConformance.DecodeCSVBindingsTestIndividual.metadata.id: .decodeCSVBindings
        case SPARQLConformance.DecodeTSVBindingsTestIndividual.metadata.id: .decodeTSVBindings
        case SPARQLConformance.RenderQueryTestIndividual.metadata.id: .renderQuery
        case SPARQLConformance.ProtocolGetQueryRequestTestIndividual.metadata.id: .buildGETQueryRequest
        case SPARQLConformance.ProtocolPostQueryRequestTestIndividual.metadata.id: .buildPOSTQueryRequest
        case SPARQLConformance.ProtocolPostUpdateRequestTestIndividual.metadata.id: .buildPOSTUpdateRequest
        case SPARQLConformance.GraphStoreGetDefaultRequestTestIndividual.metadata.id: .buildGETDefaultGraphStoreRequest
        case SPARQLConformance.GraphStoreHeadNamedRequestTestIndividual.metadata.id: .buildHEADNamedGraphStoreRequest
        case SPARQLConformance.GraphStorePostServiceRequestTestIndividual.metadata.id: .buildPOSTServiceGraphStoreRequest
        case SPARQLConformance.GraphStorePutNamedRequestTestIndividual.metadata.id: .buildPUTNamedGraphStoreRequest
        case SPARQLConformance.GraphStoreDeleteNamedRequestTestIndividual.metadata.id: .buildDELETENamedGraphStoreRequest
        case TestManifest.QueryEvaluationTestIndividual.metadata.id:
            graph.literal(node, SPARQLConformance.query.metadata.id).map(SPARQLConformanceRunner.isGraphQuery) == true
                ? .buildPOSTGraphQueryRequest
                : .buildPOSTQueryRequest
        case TestManifest.UpdateEvaluationTestIndividual.metadata.id: .buildPOSTUpdateRequest
        case TestManifest.CSVResultFormatTestIndividual.metadata.id: .decodeCSVBindings
        default: nil
        }
    }

    /// The document a case reads: its `mf:result`, or the query or update its
    /// `mf:action` names.
    private func fixtureFile(of node: SubjectTerm, action: SubjectTerm?, in graph: ManifestGraph) -> String? {
        if let result = graph.iris(node, TestManifest.result.metadata.id).first {
            return fileName(of: result)
        }
        if case .iri(let document)? = graph.object(node, TestManifest.action.metadata.id) {
            return fileName(of: document)
        }
        guard let action else { return nil }
        let document = graph.iris(action, QueryTest.query.metadata.id).first
            ?? graph.iris(action, UpdateTest.request.metadata.id).first
        return document.map(fileName(of:))
    }

    private func fileName(of iri: IRI) -> String {
        URL(string: iri.rawValue)?.lastPathComponent ?? iri.rawValue
    }

    private func identifier(of node: SubjectTerm) -> String {
        switch node {
        case .iri(let iri):
            if let fragment = URL(string: iri.rawValue)?.fragment { return fragment }
            return fileName(of: iri)
        case .blankNode(let blank):
            return blank.identifier
        }
    }
}

/// A decoded manifest, read by pattern.
struct ManifestGraph {
    let triples: [DecodedTriple]

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
