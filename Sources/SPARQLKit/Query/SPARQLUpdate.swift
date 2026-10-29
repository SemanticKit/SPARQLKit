import IRIKit
import RDFFormats

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
        case .named(let iri): "GRAPH " + SPARQLTermWriter().write(iri)
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
        case .named(let iri): "GRAPH " + SPARQLTermWriter().write(iri)
        }
    }
}

/// One operation of an update request (SPARQL 1.2 Update §3).
public enum SPARQLUpdateOperation: Hashable, Sendable {
    /// `INSERT DATA`, into the default graph or a named graph (§3.1.1).
    case insertData([DecodedTriple], graph: IRI? = nil)
    /// `DELETE DATA`, from the default graph or a named graph (§3.1.2).
    case deleteData([DecodedTriple], graph: IRI? = nil)
    /// `[WITH g] DELETE { … } INSERT { … } WHERE { … }` (§3.1.3).
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

    func render() -> String {
        let writer = SPARQLTermWriter()
        var lines = SPARQLLines()
        func data(_ keyword: String, _ triples: [DecodedTriple], _ graph: IRI?) {
            lines.block(keyword) { lines in
                if let graph {
                    lines.block("GRAPH " + writer.write(graph)) { lines in
                        for triple in triples { lines.append(writer.write(triple)) }
                    }
                } else {
                    for triple in triples { lines.append(writer.write(triple)) }
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
            if let with { lines.append("WITH " + writer.write(with)) }
            if !delete.isEmpty {
                lines.block("DELETE") { lines in for pattern in delete { lines.append(pattern.render()) } }
            }
            if !insert.isEmpty {
                lines.block("INSERT") { lines in for pattern in insert { lines.append(pattern.render()) } }
            }
            lines.block("WHERE") { SPARQLPattern.render(patterns, into: &$0) }
        case .load(let source, let graph, let silent):
            lines.append("LOAD " + silence(silent) + writer.write(source) + (graph.map { " INTO GRAPH " + writer.write($0) } ?? ""))
        case .clear(let target, let silent):
            lines.append("CLEAR " + silence(silent) + target.render())
        case .create(let graph, let silent):
            lines.append("CREATE " + silence(silent) + "GRAPH " + writer.write(graph))
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
    public var operations: [SPARQLUpdateOperation]

    public init(_ operations: [SPARQLUpdateOperation]) {
        self.operations = operations
    }

    public func render() -> String {
        operations.map { $0.render() }.joined(separator: " ;\n")
    }
}
