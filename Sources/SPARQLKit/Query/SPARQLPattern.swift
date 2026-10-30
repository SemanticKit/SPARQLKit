import IRIKit

/// An element of a group graph pattern (SPARQL 1.2 Query Language §5 to §11).
public indirect enum SPARQLPattern: Hashable, Sendable {
    /// A triple pattern.
    case triple(SPARQLTriplePattern)
    /// A nested group, `{ … }`.
    case group([SPARQLPattern])
    /// `OPTIONAL { … }` (§6).
    case optional([SPARQLPattern])
    /// `{ … } UNION { … }` (§7).
    case union([[SPARQLPattern]])
    /// `MINUS { … }` (§8.2).
    case minus([SPARQLPattern])
    /// `GRAPH name { … }` (§13.3), where the name is an IRI or a variable.
    case graph(SPARQLGraphName, [SPARQLPattern])
    /// `SERVICE endpoint { … }` (SPARQL 1.2 Federated Query §3).
    case service(IRI, silent: Bool, [SPARQLPattern])
    /// `FILTER(expression)` (§17).
    case filter(SPARQLExpression)
    /// `BIND(expression AS ?variable)` (§10.1).
    case bind(SPARQLExpression, as: Variable)
    /// Inline data (§10.2).
    case values(SPARQLValues)
    /// A subquery (§12).
    case subquery(SPARQLSelectQuery)

    /// The variables this pattern can bind.
    public var boundVariables: Set<Variable> {
        switch self {
        case .triple(let pattern):
            pattern.variables
        case .group(let patterns), .optional(let patterns), .minus(let patterns), .service(_, _, let patterns):
            Self.boundVariables(of: patterns)
        case .union(let branches):
            branches.reduce(into: []) { $0.formUnion(Self.boundVariables(of: $1)) }
        case .graph(let name, let patterns):
            name.variables.union(Self.boundVariables(of: patterns))
        case .filter:
            []
        case .bind(_, let variable):
            [variable]
        case .values(let values):
            Set(values.variables)
        case .subquery(let query):
            query.projectedVariables
        }
    }

    /// The variables the expressions in this pattern read.
    public var expressionVariables: Set<Variable> {
        switch self {
        case .triple, .values, .subquery:
            []
        case .group(let patterns), .optional(let patterns), .minus(let patterns),
             .graph(_, let patterns), .service(_, _, let patterns):
            Self.expressionVariables(of: patterns)
        case .union(let branches):
            branches.reduce(into: []) { $0.formUnion(Self.expressionVariables(of: $1)) }
        case .filter(let expression), .bind(let expression, _):
            expression.variables
        }
    }

    /// The subqueries this pattern holds, however deeply grouped.
    var subqueries: [SPARQLSelectQuery] {
        switch self {
        case .subquery(let query):
            [query]
        case .group(let patterns), .optional(let patterns), .minus(let patterns),
             .graph(_, let patterns), .service(_, _, let patterns):
            patterns.flatMap(\.subqueries)
        case .union(let branches):
            branches.flatMap { $0.flatMap(\.subqueries) }
        case .triple, .filter, .bind, .values:
            []
        }
    }

    static func boundVariables(of patterns: [SPARQLPattern]) -> Set<Variable> {
        patterns.reduce(into: []) { $0.formUnion($1.boundVariables) }
    }

    static func expressionVariables(of patterns: [SPARQLPattern]) -> Set<Variable> {
        patterns.reduce(into: []) { $0.formUnion($1.expressionVariables) }
    }

    func render(into lines: inout SPARQLLines) {
        let writer = SPARQLTermWriter()
        switch self {
        case .triple(let pattern):
            lines.append(pattern.render())
        case .group(let patterns):
            lines.block("") { Self.render(patterns, into: &$0) }
        case .optional(let patterns):
            lines.block("OPTIONAL") { Self.render(patterns, into: &$0) }
        case .union(let branches):
            for (index, branch) in branches.enumerated() {
                lines.block(index == 0 ? "" : "UNION") { Self.render(branch, into: &$0) }
            }
        case .minus(let patterns):
            lines.block("MINUS") { Self.render(patterns, into: &$0) }
        case .graph(let name, let patterns):
            lines.block("GRAPH " + name.render()) { Self.render(patterns, into: &$0) }
        case .service(let endpoint, let silent, let patterns):
            lines.block("SERVICE " + (silent ? "SILENT " : "") + writer.write(endpoint)) {
                Self.render(patterns, into: &$0)
            }
        case .filter(let expression):
            lines.append("FILTER(" + expression.render() + ")")
        case .bind(let expression, let variable):
            lines.append("BIND(" + expression.render() + " AS " + writer.write(variable) + ")")
        case .values(let values):
            values.render(into: &lines)
        case .subquery(let query):
            lines.block("") { query.render(into: &$0) }
        }
    }

    static func render(_ patterns: [SPARQLPattern], into lines: inout SPARQLLines) {
        for pattern in patterns { pattern.render(into: &lines) }
    }

    static func renderInline(_ patterns: [SPARQLPattern]) -> String {
        var lines = SPARQLLines()
        render(patterns, into: &lines)
        return lines.lines.map { String($0.drop(while: \.isWhitespace)) }.joined(separator: " ")
    }
}
