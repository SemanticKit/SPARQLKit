import Foundation

public enum SPARQLGraphTarget: Hashable, Sendable {
    case `default`
    case named(String)
    case all
    case allNamed

    var keyword: String {
        switch self {
        case .default:
            return "DEFAULT"
        case let .named(iri):
            return "GRAPH <\(iri)>"
        case .all:
            return "ALL"
        case .allNamed:
            return "NAMED"
        }
    }
}

public enum SPARQLUpdateOperation: Hashable, Sendable {
    case insertData(triples: [String])
    case deleteData(triples: [String])
    case deleteInsertWhere(delete: [String], insert: [String], wherePatterns: [String])

    case load(source: String, intoGraph: String?)
    case clear(target: SPARQLGraphTarget, silent: Bool)
    case create(graph: String, silent: Bool)
    case drop(target: SPARQLGraphTarget, silent: Bool)

    case copy(from: String, to: String, silent: Bool)
    case move(from: String, to: String, silent: Bool)
    case add(from: String, to: String, silent: Bool)

    public func render() -> String {
        switch self {
        case let .insertData(triples):
            return "INSERT DATA {\n\(indent(triples))\n}"

        case let .deleteData(triples):
            return "DELETE DATA {\n\(indent(triples))\n}"

        case let .deleteInsertWhere(deletes, inserts, wherePatterns):
            var lines: [String] = []
            if !deletes.isEmpty {
                lines.append("DELETE {\n\(indent(deletes))\n}")
            }
            if !inserts.isEmpty {
                lines.append("INSERT {\n\(indent(inserts))\n}")
            }
            lines.append("WHERE {\n\(indent(wherePatterns))\n}")
            return lines.joined(separator: "\n")

        case let .load(source, intoGraph):
            if let intoGraph {
                return "LOAD <\(source)> INTO GRAPH <\(intoGraph)>"
            }
            return "LOAD <\(source)>"

        case let .clear(target, silent):
            return "CLEAR \(silent ? "SILENT " : "")\(target.keyword)"

        case let .create(graph, silent):
            return "CREATE \(silent ? "SILENT " : "")GRAPH <\(graph)>"

        case let .drop(target, silent):
            return "DROP \(silent ? "SILENT " : "")\(target.keyword)"

        case let .copy(from, to, silent):
            return "COPY \(silent ? "SILENT " : "")GRAPH <\(from)> TO GRAPH <\(to)>"

        case let .move(from, to, silent):
            return "MOVE \(silent ? "SILENT " : "")GRAPH <\(from)> TO GRAPH <\(to)>"

        case let .add(from, to, silent):
            return "ADD \(silent ? "SILENT " : "")GRAPH <\(from)> TO GRAPH <\(to)>"
        }
    }

    private func indent(_ lines: [String]) -> String {
        lines.map { "  \($0)" }.joined(separator: "\n")
    }
}

public struct SPARQLUpdateRequest: Hashable, Sendable {
    public var operations: [SPARQLUpdateOperation]

    public init(operations: [SPARQLUpdateOperation]) {
        self.operations = operations
    }

    public func render() -> String {
        operations.map { $0.render() }.joined(separator: ";\n")
    }
}
