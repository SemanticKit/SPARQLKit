import Foundation
import SemanticKit
import RDFKit

public enum SPARQLW3CManifestError: Error, Equatable, Sendable {
    case missingManifestNode
    case missingEntries
    case malformedEntry(String)
    case unsupportedOperation(String)
    case missingIncludeResolver
}

public struct SPARQLW3CManifestLoader {
    private enum Vocabulary {
        static let mfNamespace = "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#"
        static let qtNamespace = "http://www.w3.org/2001/sw/DataAccess/tests/test-query#"
        static let utNamespace = "http://www.w3.org/2009/sparql/tests/test-update#"
        static let skNamespace = "https://codex.local/sparqlkit/conformance#"

        static let manifest = iri("\(mfNamespace)Manifest")
        static let entries = iri("\(mfNamespace)entries")
        static let include = iri("\(mfNamespace)include")
        static let name = iri("\(mfNamespace)name")
        static let action = iri("\(mfNamespace)action")
        static let result = iri("\(mfNamespace)result")
        static let qtQuery = iri("\(qtNamespace)query")
        static let qtData = iri("\(qtNamespace)data")
        static let qtGraphData = iri("\(qtNamespace)graphData")
        static let qtGraph = iri("\(qtNamespace)graph")
        static let utRequest = iri("\(utNamespace)request")
        static let utData = iri("\(utNamespace)data")
        static let utGraphData = iri("\(utNamespace)graphData")
        static let utGraph = iri("\(utNamespace)graph")
        static let queryEvaluationTest = iri("\(mfNamespace)QueryEvaluationTest")
        static let updateEvaluationTest = iri("\(mfNamespace)UpdateEvaluationTest")
        static let csvResultFormatTest = iri("\(mfNamespace)CSVResultFormatTest")
        static let xmlResultFormatTest = iri("\(mfNamespace)XMLResultFormatTest")
        static let jsonResultFormatTest = iri("\(mfNamespace)JSONResultFormatTest")

        static let operation = iri("\(skNamespace)operation")
        static let queryTemplate = iri("\(skNamespace)queryTemplate")
        static let query = iri("\(skNamespace)query")
        static let update = iri("\(skNamespace)update")
        static let defaultGraphURI = iri("\(skNamespace)defaultGraphURI")
        static let namedGraphURI = iri("\(skNamespace)namedGraphURI")
        static let usingGraphURI = iri("\(skNamespace)usingGraphURI")
        static let usingNamedGraphURI = iri("\(skNamespace)usingNamedGraphURI")
        static let expectVariableCount = iri("\(skNamespace)expectVariableCount")
        static let expectBindingCount = iri("\(skNamespace)expectBindingCount")
        static let expectBoolean = iri("\(skNamespace)expectBoolean")
        static let expectContains = iri("\(skNamespace)expectContains")
        static let expectURLContains = iri("\(skNamespace)expectURLContains")
        static let expectBodyContains = iri("\(skNamespace)expectBodyContains")
        static let expectHeaderContains = iri("\(skNamespace)expectHeaderContains")

        static let decodeJSONBindingsTest = iri("\(skNamespace)DecodeJSONBindingsTest")
        static let decodeJSONBooleanTest = iri("\(skNamespace)DecodeJSONBooleanTest")
        static let decodeXMLBindingsTest = iri("\(skNamespace)DecodeXMLBindingsTest")
        static let decodeXMLBooleanTest = iri("\(skNamespace)DecodeXMLBooleanTest")
        static let decodeCSVBindingsTest = iri("\(skNamespace)DecodeCSVBindingsTest")
        static let decodeTSVBindingsTest = iri("\(skNamespace)DecodeTSVBindingsTest")
        static let renderQueryTest = iri("\(skNamespace)RenderQueryTest")
        static let protocolGetQueryRequestTest = iri("\(skNamespace)ProtocolGetQueryRequestTest")
        static let protocolPostQueryRequestTest = iri("\(skNamespace)ProtocolPostQueryRequestTest")
        static let protocolPostUpdateRequestTest = iri("\(skNamespace)ProtocolPostUpdateRequestTest")
        static let graphStoreGetDefaultRequestTest = iri("\(skNamespace)GraphStoreGetDefaultRequestTest")
        static let graphStoreHeadNamedRequestTest = iri("\(skNamespace)GraphStoreHeadNamedRequestTest")
        static let graphStorePostServiceRequestTest = iri("\(skNamespace)GraphStorePostServiceRequestTest")
        static let graphStorePutNamedRequestTest = iri("\(skNamespace)GraphStorePutNamedRequestTest")
        static let graphStoreDeleteNamedRequestTest = iri("\(skNamespace)GraphStoreDeleteNamedRequestTest")

        static func iri(_ raw: String) -> IRI {
            try! IRI(raw)
        }
    }

    public init() {}

    public func loadSuite(
        from data: Data,
        baseURL: URL?,
        loadIncludedManifest: ((String) throws -> Data)? = nil
    ) throws -> SPARQLConformanceSuite {
        guard let turtle = String(data: data, encoding: .utf8) else {
            throw SPARQLConformanceError.assertionFailed("Manifest is not UTF-8 Turtle.")
        }
        return try loadSuite(
            turtle: turtle,
            baseURL: baseURL,
            loadIncludedManifest: loadIncludedManifest
        )
    }

    public func loadSuite(
        turtle: String,
        baseURL: URL? = nil,
        loadIncludedManifest: ((String) throws -> Data)? = nil
    ) throws -> SPARQLConformanceSuite {
        let baseIRI = try baseURL.flatMap { try IRI($0.absoluteString) }
        let graph = try Graph(turtle: turtle, baseIRI: baseIRI)

        let manifestSubject = try findManifestSubject(in: graph)
        let suiteName = literalValue(
            firstObject(in: graph, subject: manifestSubject, predicate: Vocabulary.name)
        ) ?? "W3C conformance subset"

        if let entriesHead = firstObject(in: graph, subject: manifestSubject, predicate: Vocabulary.entries) {
            let entryNodes = try expandRDFList(startingAt: entriesHead, in: graph)
            let cases = try entryNodes.map { try parseCase(from: $0, in: graph) }
            return SPARQLConformanceSuite(name: suiteName, cases: cases)
        }

        if let includeHead = firstObject(in: graph, subject: manifestSubject, predicate: Vocabulary.include) {
            guard let loadIncludedManifest else {
                throw SPARQLW3CManifestError.missingIncludeResolver
            }

            let includeTerms = try expandRDFListTerms(startingAt: includeHead, in: graph)
            var mergedCases: [SPARQLConformanceCase] = []

            for includeTerm in includeTerms {
                guard let includeIRI = includeTerm.node as? IRI else {
                    throw SPARQLW3CManifestError.malformedEntry("mf:include list item must be an IRI.")
                }

                let includeURL = URL(string: includeIRI.string, relativeTo: baseURL)?.absoluteURL
                let includeFile = fileName(from: includeIRI)
                let includeData = try loadIncludedManifest(includeFile)
                let childSuite = try loadSuite(
                    from: includeData,
                    baseURL: includeURL,
                    loadIncludedManifest: loadIncludedManifest
                )
                mergedCases.append(contentsOf: childSuite.cases)
            }

            return SPARQLConformanceSuite(name: suiteName, cases: mergedCases)
        }

        throw SPARQLW3CManifestError.missingEntries
    }

    private func findManifestSubject(in graph: Graph) throws -> RDFSubject {
        for triple in graph.triples where triple.predicate == RDF.Vocabulary.type {
            if let typeIRI = triple.object.node as? IRI, typeIRI == Vocabulary.manifest {
                return triple.subject
            }
        }
        throw SPARQLW3CManifestError.missingManifestNode
    }

    private func parseCase(from node: RDFSubject, in graph: Graph) throws -> SPARQLConformanceCase {
        let id = identifier(for: node)

        let operation = try parseOperation(from: node, in: graph)
        let fixtureFile = try resolveFixtureFile(for: node, in: graph)

        let queryTemplate = literalValue(
            firstObject(in: graph, subject: node, predicate: Vocabulary.queryTemplate)
        ).flatMap(SPARQLConformanceQueryTemplate.init(rawValue:))
        let queryText = literalValue(
            firstObject(in: graph, subject: node, predicate: Vocabulary.query)
        )
        let updateText = literalValue(
            firstObject(in: graph, subject: node, predicate: Vocabulary.update)
        )
        var defaultGraphURIs = objects(in: graph, subject: node, predicate: Vocabulary.defaultGraphURI).compactMap(literalValue)
        var namedGraphURIs = objects(in: graph, subject: node, predicate: Vocabulary.namedGraphURI).compactMap(literalValue)
        var usingGraphURIs = objects(in: graph, subject: node, predicate: Vocabulary.usingGraphURI).compactMap(literalValue)
        var usingNamedGraphURIs = objects(in: graph, subject: node, predicate: Vocabulary.usingNamedGraphURI).compactMap(literalValue)

        let inferred = try resolveActionDatasets(for: node, in: graph)
        defaultGraphURIs.append(contentsOf: inferred.defaultGraphURIs)
        namedGraphURIs.append(contentsOf: inferred.namedGraphURIs)
        usingGraphURIs.append(contentsOf: inferred.usingGraphURIs)
        usingNamedGraphURIs.append(contentsOf: inferred.usingNamedGraphURIs)

        let expectVariableCount = intLiteralValue(
            firstObject(in: graph, subject: node, predicate: Vocabulary.expectVariableCount)
        )
        let expectBindingCount = intLiteralValue(
            firstObject(in: graph, subject: node, predicate: Vocabulary.expectBindingCount)
        )
        let expectBoolean = boolLiteralValue(
            firstObject(in: graph, subject: node, predicate: Vocabulary.expectBoolean)
        )

        let expectContains = objects(in: graph, subject: node, predicate: Vocabulary.expectContains)
            .compactMap(literalValue)
        let expectURLContains = objects(in: graph, subject: node, predicate: Vocabulary.expectURLContains)
            .compactMap(literalValue)
        let expectBodyContains = objects(in: graph, subject: node, predicate: Vocabulary.expectBodyContains)
            .compactMap(literalValue)
        let expectHeaderContains = objects(in: graph, subject: node, predicate: Vocabulary.expectHeaderContains)
            .compactMap(literalValue)

        if operation == .renderQuery, queryTemplate == nil {
            throw SPARQLW3CManifestError.malformedEntry("\(id): render query case missing sk:queryTemplate")
        }

        return SPARQLConformanceCase(
            id: id,
            operation: operation,
            fixtureFile: fixtureFile,
            queryTemplate: queryTemplate,
            queryText: queryText,
            updateText: updateText,
            defaultGraphURIs: defaultGraphURIs,
            namedGraphURIs: namedGraphURIs,
            usingGraphURIs: usingGraphURIs,
            usingNamedGraphURIs: usingNamedGraphURIs,
            expectVariableCount: expectVariableCount,
            expectBindingCount: expectBindingCount,
            expectBoolean: expectBoolean,
            expectContains: expectContains,
            expectURLContains: expectURLContains,
            expectBodyContains: expectBodyContains,
            expectHeaderContains: expectHeaderContains
        )
    }

    private func parseOperation(from node: RDFSubject, in graph: Graph) throws -> SPARQLConformanceOperation {
        if let explicit = literalValue(firstObject(in: graph, subject: node, predicate: Vocabulary.operation)),
           let op = SPARQLConformanceOperation(rawValue: explicit)
        {
            return op
        }

        let types = objects(in: graph, subject: node, predicate: RDF.Vocabulary.type)
            .compactMap { $0.node as? IRI }

        if types.contains(Vocabulary.decodeJSONBindingsTest) { return .decodeJSONBindings }
        if types.contains(Vocabulary.decodeJSONBooleanTest) { return .decodeJSONBoolean }
        if types.contains(Vocabulary.decodeXMLBindingsTest) { return .decodeXMLBindings }
        if types.contains(Vocabulary.decodeXMLBooleanTest) { return .decodeXMLBoolean }
        if types.contains(Vocabulary.decodeCSVBindingsTest) { return .decodeCSVBindings }
        if types.contains(Vocabulary.decodeTSVBindingsTest) { return .decodeTSVBindings }
        if types.contains(Vocabulary.renderQueryTest) { return .renderQuery }
        if types.contains(Vocabulary.protocolGetQueryRequestTest) { return .buildGETQueryRequest }
        if types.contains(Vocabulary.protocolPostQueryRequestTest) { return .buildPOSTQueryRequest }
        if types.contains(Vocabulary.protocolPostUpdateRequestTest) { return .buildPOSTUpdateRequest }
        if types.contains(Vocabulary.graphStoreGetDefaultRequestTest) { return .buildGETDefaultGraphStoreRequest }
        if types.contains(Vocabulary.graphStoreHeadNamedRequestTest) { return .buildHEADNamedGraphStoreRequest }
        if types.contains(Vocabulary.graphStorePostServiceRequestTest) { return .buildPOSTServiceGraphStoreRequest }
        if types.contains(Vocabulary.graphStorePutNamedRequestTest) { return .buildPUTNamedGraphStoreRequest }
        if types.contains(Vocabulary.graphStoreDeleteNamedRequestTest) { return .buildDELETENamedGraphStoreRequest }
        if types.contains(Vocabulary.queryEvaluationTest) {
            if let query = literalValue(firstObject(in: graph, subject: node, predicate: Vocabulary.query)) {
                let leading = query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                if leading.hasPrefix("CONSTRUCT") || leading.hasPrefix("DESCRIBE") {
                    return .buildPOSTGraphQueryRequest
                }
            }
            return .buildPOSTQueryRequest
        }
        if types.contains(Vocabulary.updateEvaluationTest) { return .buildPOSTUpdateRequest }
        if types.contains(Vocabulary.csvResultFormatTest) { return .decodeCSVBindings }
        if types.contains(Vocabulary.xmlResultFormatTest) { return .decodeXMLBindings }
        if types.contains(Vocabulary.jsonResultFormatTest) { return .decodeJSONBindings }

        throw SPARQLW3CManifestError.unsupportedOperation(identifier(for: node))
    }

    private func resolveFixtureFile(for node: RDFSubject, in graph: Graph) throws -> String? {
        if let result = iriObject(in: graph, subject: node, predicate: Vocabulary.result) {
            return fileName(from: result)
        }

        guard let action = firstObject(in: graph, subject: node, predicate: Vocabulary.action) else {
            return nil
        }

        if let actionIRI = action.node as? IRI {
            return fileName(from: actionIRI)
        }

        guard let actionNode = action.node as? any SemanticKit.RDFSubject else {
            return nil
        }
        let actionSubject = try RDFSubject(actionNode)

        if let queryIRI = iriObject(in: graph, subject: actionSubject, predicate: Vocabulary.qtQuery) {
            return fileName(from: queryIRI)
        }
        if let requestIRI = iriObject(in: graph, subject: actionSubject, predicate: Vocabulary.utRequest) {
            return fileName(from: requestIRI)
        }

        return nil
    }

    private func resolveActionDatasets(
        for node: RDFSubject,
        in graph: Graph
    ) throws -> (defaultGraphURIs: [String], namedGraphURIs: [String], usingGraphURIs: [String], usingNamedGraphURIs: [String]) {
        guard let action = firstObject(in: graph, subject: node, predicate: Vocabulary.action),
              let actionNode = action.node as? any SemanticKit.RDFSubject
        else {
            return ([], [], [], [])
        }

        let actionSubject = try RDFSubject(actionNode)
        let queryDefault = iriObjects(in: graph, subject: actionSubject, predicate: Vocabulary.qtData).map(\.string)
        let queryNamed = try namedGraphIRIs(
            in: graph,
            subject: actionSubject,
            graphDataPredicate: Vocabulary.qtGraphData,
            graphPredicate: Vocabulary.qtGraph
        )
        let updateDefault = iriObjects(in: graph, subject: actionSubject, predicate: Vocabulary.utData).map(\.string)
        let updateNamed = try namedGraphIRIs(
            in: graph,
            subject: actionSubject,
            graphDataPredicate: Vocabulary.utGraphData,
            graphPredicate: Vocabulary.utGraph
        )

        return (
            defaultGraphURIs: queryDefault,
            namedGraphURIs: queryNamed,
            usingGraphURIs: updateDefault,
            usingNamedGraphURIs: updateNamed
        )
    }

    private func namedGraphIRIs(
        in graph: Graph,
        subject: RDFSubject,
        graphDataPredicate: IRI,
        graphPredicate: IRI
    ) throws -> [String] {
        var result: [String] = []
        for term in objects(in: graph, subject: subject, predicate: graphDataPredicate) {
            guard let node = term.node as? any SemanticKit.RDFSubject else {
                continue
            }
            let bnodeSubject = try RDFSubject(node)
            result.append(contentsOf: iriObjects(in: graph, subject: bnodeSubject, predicate: graphPredicate).map(\.string))
        }
        return result
    }

    private func expandRDFList(startingAt head: RDFTerm, in graph: Graph) throws -> [RDFSubject] {
        let terms = try expandRDFListTerms(startingAt: head, in: graph)
        return try terms.map { term in
            guard let subjectNode = term.node as? any SemanticKit.RDFSubject else {
                throw SPARQLW3CManifestError.malformedEntry("RDF list item is not a valid subject.")
            }
            return try RDFSubject(subjectNode)
        }
    }

    private func expandRDFListTerms(startingAt head: RDFTerm, in graph: Graph) throws -> [RDFTerm] {
        var terms: [RDFTerm] = []
        var cursor = head

        while true {
            if let iri = cursor.node as? IRI, iri == RDF.Vocabulary.nilValue {
                return terms
            }

            guard let listNode = cursor.node as? any SemanticKit.RDFSubject else {
                throw SPARQLW3CManifestError.malformedEntry("List node is not a valid RDF subject.")
            }
            let listSubject = try RDFSubject(listNode)

            guard let first = firstObject(in: graph, subject: listSubject, predicate: RDF.Vocabulary.first) else {
                throw SPARQLW3CManifestError.malformedEntry("Malformed mf:entries RDF list: missing rdf:first.")
            }
            terms.append(first)

            guard let rest = firstObject(in: graph, subject: listSubject, predicate: RDF.Vocabulary.rest) else {
                throw SPARQLW3CManifestError.malformedEntry("Malformed mf:entries RDF list: missing rdf:rest.")
            }
            cursor = rest
        }
    }

    private func objects(in graph: Graph, subject: RDFSubject, predicate: IRI) -> [RDFTerm] {
        graph.triples
            .filter { $0.subject == subject && $0.predicate == predicate }
            .map(\.object)
    }

    private func firstObject(in graph: Graph, subject: RDFSubject, predicate: IRI) -> RDFTerm? {
        objects(in: graph, subject: subject, predicate: predicate).first
    }

    private func iriObject(in graph: Graph, subject: RDFSubject, predicate: IRI) -> IRI? {
        firstObject(in: graph, subject: subject, predicate: predicate)?.node as? IRI
    }

    private func iriObjects(in graph: Graph, subject: RDFSubject, predicate: IRI) -> [IRI] {
        objects(in: graph, subject: subject, predicate: predicate).compactMap { $0.node as? IRI }
    }

    private func literalValue(_ object: RDFTerm?) -> String? {
        guard let literal = object?.node as? Literal else {
            return nil
        }
        return literal.lexicalForm
    }

    private func intLiteralValue(_ object: RDFTerm?) -> Int? {
        guard let raw = literalValue(object) else {
            return nil
        }
        return Int(raw)
    }

    private func boolLiteralValue(_ object: RDFTerm?) -> Bool? {
        guard let raw = literalValue(object)?.lowercased() else {
            return nil
        }
        return raw == "true" ? true : (raw == "false" ? false : nil)
    }

    private func fileName(from iri: IRI) -> String {
        URL(string: iri.string)?.lastPathComponent ?? iri.string
    }

    private func identifier(for node: RDFSubject) -> String {
        if let iri = node.node as? IRI {
            return URL(string: iri.string)?.lastPathComponent ?? iri.string
        }
        if let blank = node.node as? BlankNode {
            return blank.identifier
        }
        return node.description
    }
}
