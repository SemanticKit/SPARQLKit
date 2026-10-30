import IRIKit

/// The graphs a `CLEAR` or `DROP` operation acts on
/// (SPARQL 1.2 Update §3.2.2, `GraphRefAll`).
public enum SPARQLGraphTarget: Hashable, Sendable {
    case `default`
    case named(IRI)
    case all
    case allNamed

    func render() -> String {
        switch self {
        case .default: "DEFAULT"
        case .named(let iri): "GRAPH " + iri.render()
        case .all: "ALL"
        case .allNamed: "NAMED"
        }
    }
}

/// The graph a `COPY`, `MOVE` or `ADD` operation reads or writes
/// (SPARQL 1.2 Update §3.2.4, `GraphOrDefault`).
public enum SPARQLGraphReference: Hashable, Sendable {
    case `default`
    case named(IRI)

    func render() -> String {
        switch self {
        case .default: "DEFAULT"
        case .named(let iri): "GRAPH " + iri.render()
        }
    }
}

/// One operation of an update request (SPARQL 1.2 Update §3).
public enum SPARQLUpdateOperation: Hashable, Sendable {
    /// `INSERT DATA`, into the default graph or a named graph (§3.1.1). The
    /// triples are ground: no variables and no property paths.
    case insertData([SPARQLTriplePattern], graph: IRI? = nil)
    /// `DELETE DATA`, from the default graph or a named graph (§3.1.2). The
    /// triples are ground and hold no blank nodes.
    case deleteData([SPARQLTriplePattern], graph: IRI? = nil)
    /// `[WITH g] DELETE { … } INSERT { … } WHERE { … }` (§3.1.3). The
    /// templates hold no property paths, and the `DELETE` template no blank
    /// nodes.
    case modify(with: IRI? = nil, delete: [SPARQLTriplePattern], insert: [SPARQLTriplePattern], where: [SPARQLPattern])
    /// `LOAD` (§3.1.4).
    case load(IRI, into: IRI? = nil, silent: Bool = false)
    /// `CLEAR` (§3.1.5).
    case clear(SPARQLGraphTarget, silent: Bool = false)
    /// `CREATE` (§3.2.1).
    case create(IRI, silent: Bool = false)
    /// `DROP` (§3.2.2).
    case drop(SPARQLGraphTarget, silent: Bool = false)
    /// `COPY` (§3.2.3).
    case copy(from: SPARQLGraphReference, to: SPARQLGraphReference, silent: Bool = false)
    /// `MOVE` (§3.2.4).
    case move(from: SPARQLGraphReference, to: SPARQLGraphReference, silent: Bool = false)
    /// `ADD` (§3.2.5).
    case add(from: SPARQLGraphReference, to: SPARQLGraphReference, silent: Bool = false)

    /// Checks the operation against the grammar (SPARQL 1.2 Query Language
    /// §19.8). `QuadData` is ground ("Variables are not allowed in
    /// QuadData"); "Blank node syntax is not allowed in DELETE WHERE, the
    /// DeleteClause for DELETE, nor in DELETE DATA"; and `QuadPattern`
    /// templates are triples, not property paths.
    func validate() throws {
        switch self {
        case .insertData(let triples, _):
            try Template.insertData.validate(triples)
        case .deleteData(let triples, _):
            try Template.deleteData.validate(triples)
        case .modify(_, let delete, let insert, _):
            try Template.deleteClause.validate(delete)
            try Template.insertClause.validate(insert)
        case .load, .clear, .create, .drop, .copy, .move, .add:
            break
        }
    }

    /// The grammar positions (SPARQL 1.2 Query Language §19.8) an update
    /// operation's triples sit in, each with the triples it admits.
    enum Template {
        /// `INSERT DATA QuadData`.
        case insertData
        /// `DELETE DATA QuadData`.
        case deleteData
        /// `DeleteClause` of `DELETE ... WHERE`.
        case deleteClause
        /// `InsertClause` of `INSERT ... WHERE`.
        case insertClause

        var name: String {
            switch self {
            case .insertData: "INSERT DATA"
            case .deleteData: "DELETE DATA"
            case .deleteClause: "A DELETE template"
            case .insertClause: "An INSERT template"
            }
        }

        func validate(_ triples: [SPARQLTriplePattern]) throws {
            for triple in triples {
                if triple.verb.isPath {
                    throw SPARQLError.invalidRequest("\(name) cannot hold a property path.")
                }
                switch self {
                case .insertData, .deleteData:
                    if !triple.variables.isEmpty {
                        throw SPARQLError.invalidRequest("\(name) holds ground triples only, not variables.")
                    }
                case .deleteClause, .insertClause:
                    break
                }
                switch self {
                case .deleteData, .deleteClause:
                    if triple.subject.containsBlankNode || triple.object.containsBlankNode {
                        throw SPARQLError.invalidRequest("\(name) cannot hold a blank node.")
                    }
                case .insertData, .insertClause:
                    break
                }
            }
        }
    }

    func render() -> String {
        var lines = SPARQLLines()
        func data(_ keyword: String, _ triples: [SPARQLTriplePattern], _ graph: IRI?) {
            lines.block(keyword) { lines in
                if let graph {
                    lines.block("GRAPH " + graph.render()) { lines in
                        for triple in triples { lines.append(triple.render()) }
                    }
                } else {
                    for triple in triples { lines.append(triple.render()) }
                }
            }
        }
        func silence(_ silent: Bool) -> String { silent ? "SILENT " : "" }

        switch self {
        case .insertData(let triples, let graph):
            data("INSERT DATA", triples, graph)
        case .deleteData(let triples, let graph):
            data("DELETE DATA", triples, graph)
        case .modify(let with, let delete, let insert, let patterns):
            if let with { lines.append("WITH " + with.render()) }
            if !delete.isEmpty {
                lines.block("DELETE") { lines in for pattern in delete { lines.append(pattern.render()) } }
            }
            if !insert.isEmpty {
                lines.block("INSERT") { lines in for pattern in insert { lines.append(pattern.render()) } }
            }
            lines.block("WHERE") { SPARQLPattern.render(patterns, into: &$0) }
        case .load(let source, let graph, let silent):
            lines.append("LOAD " + silence(silent) + source.render() + (graph.map { " INTO GRAPH " + $0.render() } ?? ""))
        case .clear(let target, let silent):
            lines.append("CLEAR " + silence(silent) + target.render())
        case .create(let graph, let silent):
            lines.append("CREATE " + silence(silent) + "GRAPH " + graph.render())
        case .drop(let target, let silent):
            lines.append("DROP " + silence(silent) + target.render())
        case .copy(let from, let to, let silent):
            lines.append("COPY " + silence(silent) + from.render() + " TO " + to.render())
        case .move(let from, let to, let silent):
            lines.append("MOVE " + silence(silent) + from.render() + " TO " + to.render())
        case .add(let from, let to, let silent):
            lines.append("ADD " + silence(silent) + from.render() + " TO " + to.render())
        }
        return lines.text
    }
}

/// An update request: a sequence of operations (SPARQL 1.2 Update §3).
public struct SPARQLUpdateRequest: SPARQLQueryRenderable, Hashable {
    public let operations: [SPARQLUpdateOperation]

    /// - Throws: ``SPARQLError/invalidRequest(_:)`` when an operation breaks
    ///   the SPARQL 1.2 Update grammar, such as a blank node in `DELETE DATA`.
    public init(_ operations: [SPARQLUpdateOperation]) throws {
        for operation in operations { try operation.validate() }
        self.operations = operations
    }

    public func render() -> String {
        operations.map { $0.render() }.joined(separator: " ;\n")
    }
}
