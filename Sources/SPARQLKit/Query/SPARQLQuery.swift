import Foundation
import IRIKit

public protocol SPARQLQueryRenderable: Sendable {
    func render() -> String
}

public indirect enum SPARQLPropertyPath: Hashable, Sendable {
    case iri(IRI)
    case inverse(SPARQLPropertyPath)
    case sequence([SPARQLPropertyPath])
    case alternative([SPARQLPropertyPath])
    case zeroOrMore(SPARQLPropertyPath)
    case oneOrMore(SPARQLPropertyPath)
    case zeroOrOne(SPARQLPropertyPath)

    public func render() -> String {
        switch self {
        case let .iri(iri):
            return "<\(iri.rawValue)>"
        case let .inverse(path):
            return "^\(path.renderWrappedForUnary())"
        case let .sequence(parts):
            return parts.map { $0.renderWrappedForSequenceOrAlternative() }.joined(separator: "/")
        case let .alternative(parts):
            return parts.map { $0.renderWrappedForSequenceOrAlternative() }.joined(separator: "|")
        case let .zeroOrMore(path):
            return "\(path.renderWrappedForUnary())*"
        case let .oneOrMore(path):
            return "\(path.renderWrappedForUnary())+"
        case let .zeroOrOne(path):
            return "\(path.renderWrappedForUnary())?"
        }
    }

    private func renderWrappedForUnary() -> String {
        switch self {
        case .iri:
            return render()
        default:
            return "(\(render()))"
        }
    }

    private func renderWrappedForSequenceOrAlternative() -> String {
        switch self {
        case .iri, .inverse, .zeroOrMore, .oneOrMore, .zeroOrOne:
            return render()
        default:
            return "(\(render()))"
        }
    }
}

public struct SPARQLPathPattern: Hashable, Sendable {
    public let subject: String
    public let path: SPARQLPropertyPath
    public let object: String

    public init(subject: String, path: SPARQLPropertyPath, object: String) {
        self.subject = subject
        self.path = path
        self.object = object
    }

    public func render() -> String {
        "\(subject) \(path.render()) \(object) ."
    }
}

public indirect enum SPARQLExpression: Hashable, Sendable {
    case variable(Variable)
    case literal(String)
    case iri(IRI)
    case unary(SPARQLUnaryOperator, SPARQLExpression)
    case binary(SPARQLExpression, SPARQLBinaryOperator, SPARQLExpression)
    case function(String, [SPARQLExpression])

    public func render() -> String {
        switch self {
        case let .variable(variable):
            return variable.sparql
        case let .literal(value):
            return value
        case let .iri(iri):
            return "<\(iri.rawValue)>"
        case let .unary(op, expression):
            return "\(op.rawValue)(\(expression.render()))"
        case let .binary(lhs, op, rhs):
            return "(\(lhs.render()) \(op.rawValue) \(rhs.render()))"
        case let .function(name, args):
            return "\(name)(\(args.map { $0.render() }.joined(separator: ", ")))"
        }
    }
}

public enum SPARQLUnaryOperator: String, Hashable, Sendable {
    case logicalNot = "!"
    case unaryPlus = "+"
    case unaryMinus = "-"
}

public enum SPARQLBinaryOperator: String, Hashable, Sendable {
    case equal = "="
    case notEqual = "!="
    case lessThan = "<"
    case lessThanOrEqual = "<="
    case greaterThan = ">"
    case greaterThanOrEqual = ">="
    case and = "&&"
    case or = "||"
    case add = "+"
    case subtract = "-"
    case multiply = "*"
    case divide = "/"
}

public struct SPARQLSubqueryScopeIssue: Hashable, Sendable {
    public let variable: Variable
    public let subqueryProjection: Set<Variable>

    public init(variable: Variable, subqueryProjection: Set<Variable>) {
        self.variable = variable
        self.subqueryProjection = subqueryProjection
    }
}

public struct SPARQLBindClause: Hashable, Sendable {
    public let expression: String
    public let variable: Variable

    public init(expression: String, variable: Variable) {
        self.expression = expression
        self.variable = variable
    }

    public init(expression: SPARQLExpression, variable: Variable) {
        self.expression = expression.render()
        self.variable = variable
    }

    public func render() -> String {
        "BIND(\(expression) AS \(variable.sparql))"
    }
}

public struct SPARQLValuesClause: Hashable, Sendable {
    public let variables: [Variable]
    public let rows: [[String]]

    public init(variables: [Variable], rows: [[String]]) {
        self.variables = variables
        self.rows = rows
    }

    public func render() -> String {
        if variables.count == 1 {
            let variable = variables[0].sparql
            var lines = ["VALUES \(variable) {"]
            for row in rows {
                if let value = row.first {
                    lines.append("  \(value)")
                }
            }
            lines.append("}")
            return lines.joined(separator: "\n")
        }

        let header = variables.map(\.sparql).joined(separator: " ")
        var lines = ["VALUES (\(header)) {"]
        for row in rows {
            let cells = row.joined(separator: " ")
            lines.append("  (\(cells))")
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }
}

public struct SPARQLOrderByClause: Hashable, Sendable {
    public let expression: String
    public let ascending: Bool

    public init(expression: String, ascending: Bool = true) {
        self.expression = expression
        self.ascending = ascending
    }

    public func render() -> String {
        ascending ? "ASC(\(expression))" : "DESC(\(expression))"
    }
}

public struct SPARQLGraphPatternClause: Hashable, Sendable {
    public let graphIRI: IRI
    public let patterns: [String]

    public init(graphIRI: IRI, patterns: [String]) {
        self.graphIRI = graphIRI
        self.patterns = patterns
    }

    public func render() -> String {
        var lines: [String] = ["GRAPH <\(graphIRI.rawValue)> {"]
        for pattern in patterns {
            lines.append("  \(pattern)")
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }
}

public struct SPARQLSelectQuery: Hashable, Sendable, SPARQLQueryRenderable {
    public var prefixes: [String: IRI]
    public var variables: [Variable]

    public var wherePatterns: [String]
    public var optionalBlocks: [[String]]
    public var unionBlocks: [[String]]
    public var minusBlocks: [[String]]
    public var subqueries: [SPARQLSelectQuery]
    public var pathPatterns: [SPARQLPathPattern]
    public var graphBlocks: [SPARQLGraphPatternClause]
    public var filters: [String]
    public var filterExpressions: [SPARQLExpression]
    public var bindClauses: [SPARQLBindClause]
    public var valuesClauses: [SPARQLValuesClause]

    public var fromGraphs: [IRI]
    public var fromNamedGraphs: [IRI]

    public var distinct: Bool
    public var reduced: Bool
    public var groupBy: [Variable]
    public var having: [String]
    public var orderBy: [SPARQLOrderByClause]
    public var limit: Int?
    public var offset: Int?

    public init(
        prefixes: [String: IRI] = [:],
        variables: [Variable],
        wherePatterns: [String],
        optionalBlocks: [[String]] = [],
        unionBlocks: [[String]] = [],
        minusBlocks: [[String]] = [],
        subqueries: [SPARQLSelectQuery] = [],
        pathPatterns: [SPARQLPathPattern] = [],
        graphBlocks: [SPARQLGraphPatternClause] = [],
        filters: [String] = [],
        filterExpressions: [SPARQLExpression] = [],
        bindClauses: [SPARQLBindClause] = [],
        valuesClauses: [SPARQLValuesClause] = [],
        fromGraphs: [IRI] = [],
        fromNamedGraphs: [IRI] = [],
        distinct: Bool = false,
        reduced: Bool = false,
        groupBy: [Variable] = [],
        having: [String] = [],
        orderBy: [SPARQLOrderByClause] = [],
        limit: Int? = nil,
        offset: Int? = nil
    ) {
        self.prefixes = prefixes
        self.variables = variables
        self.wherePatterns = wherePatterns
        self.optionalBlocks = optionalBlocks
        self.unionBlocks = unionBlocks
        self.minusBlocks = minusBlocks
        self.subqueries = subqueries
        self.pathPatterns = pathPatterns
        self.graphBlocks = graphBlocks
        self.filters = filters
        self.filterExpressions = filterExpressions
        self.bindClauses = bindClauses
        self.valuesClauses = valuesClauses
        self.fromGraphs = fromGraphs
        self.fromNamedGraphs = fromNamedGraphs
        self.distinct = distinct
        self.reduced = reduced
        self.groupBy = groupBy
        self.having = having
        self.orderBy = orderBy
        self.limit = limit
        self.offset = offset
    }

    public func render() -> String {
        var lines: [String] = []
        for key in prefixes.keys.sorted() {
            if let iri = prefixes[key] {
                lines.append("PREFIX \(key): <\(iri.rawValue)>")
            }
        }

        var selectTokens: [String] = ["SELECT"]
        if distinct {
            selectTokens.append("DISTINCT")
        } else if reduced {
            selectTokens.append("REDUCED")
        }
        selectTokens.append(variables.map(\.sparql).joined(separator: " "))
        lines.append(selectTokens.joined(separator: " "))

        for graph in fromGraphs {
            lines.append("FROM <\(graph.rawValue)>")
        }
        for graph in fromNamedGraphs {
            lines.append("FROM NAMED <\(graph.rawValue)>")
        }

        lines.append("WHERE {")

        for pattern in wherePatterns {
            lines.append("  \(pattern)")
        }

        for pattern in pathPatterns {
            lines.append("  \(pattern.render())")
        }

        for graph in graphBlocks {
            for line in graph.render().split(separator: "\n", omittingEmptySubsequences: false) {
                lines.append("  \(line)")
            }
        }

        for block in optionalBlocks {
            lines.append("  OPTIONAL {")
            for pattern in block {
                lines.append("    \(pattern)")
            }
            lines.append("  }")
        }

        if !unionBlocks.isEmpty {
            for (index, block) in unionBlocks.enumerated() {
                if index == 0 {
                    lines.append("  {")
                } else {
                    lines.append("  UNION {")
                }
                for pattern in block {
                    lines.append("    \(pattern)")
                }
                lines.append("  }")
            }
        }

        for block in minusBlocks {
            lines.append("  MINUS {")
            for pattern in block {
                lines.append("    \(pattern)")
            }
            lines.append("  }")
        }

        for subquery in subqueries {
            var nested = subquery
            nested.prefixes = [:]
            nested.fromGraphs = []
            nested.fromNamedGraphs = []

            lines.append("  {")
            for line in nested.render().split(separator: "\n", omittingEmptySubsequences: false) {
                lines.append("    \(line)")
            }
            lines.append("  }")
        }

        for filter in filters {
            lines.append("  FILTER(\(filter))")
        }

        for filter in filterExpressions {
            lines.append("  FILTER(\(filter.render()))")
        }

        for bind in bindClauses {
            lines.append("  \(bind.render())")
        }

        for values in valuesClauses {
            for line in values.render().split(separator: "\n", omittingEmptySubsequences: false) {
                lines.append("  \(line)")
            }
        }

        lines.append("}")

        if !groupBy.isEmpty {
            lines.append("GROUP BY \(groupBy.map(\.sparql).joined(separator: " "))")
        }

        if !having.isEmpty {
            lines.append("HAVING (\(having.joined(separator: ") (")))")
        }

        if !orderBy.isEmpty {
            lines.append("ORDER BY \(orderBy.map { $0.render() }.joined(separator: " "))")
        }

        if let limit {
            lines.append("LIMIT \(limit)")
        }
        if let offset {
            lines.append("OFFSET \(offset)")
        }

        return lines.joined(separator: "\n")
    }

    public func validateSubqueryScopes() -> [SPARQLSubqueryScopeIssue] {
        var issues: [SPARQLSubqueryScopeIssue] = []
        let freeExpressionVariables = collectFreeExpressionVariables()

        for subquery in subqueries {
            let projected = Set(subquery.variables)
            let subqueryReferences = subquery.collectAllReferencedVariables()
            let unprojected = subqueryReferences.subtracting(projected)

            for variable in freeExpressionVariables.intersection(unprojected) {
                issues.append(
                    SPARQLSubqueryScopeIssue(
                        variable: variable,
                        subqueryProjection: projected
                    )
                )
            }

            issues.append(contentsOf: subquery.validateSubqueryScopes())
        }

        return Array(Set(issues)).sorted { $0.variable.rawValue < $1.variable.rawValue }
    }

    private func collectBoundVariables() -> Set<Variable> {
        var bindingSources: [String] = []
        bindingSources.append(contentsOf: wherePatterns)
        bindingSources.append(contentsOf: optionalBlocks.flatMap { $0 })
        bindingSources.append(contentsOf: unionBlocks.flatMap { $0 })
        bindingSources.append(contentsOf: minusBlocks.flatMap { $0 })
        bindingSources.append(contentsOf: graphBlocks.flatMap { $0.patterns })
        bindingSources.append(contentsOf: pathPatterns.map { "\($0.subject) \($0.object)" })
        bindingSources.append(contentsOf: valuesClauses.flatMap { $0.variables.map(\.sparql) })

        var bound = extractVariables(from: bindingSources)
        bound.formUnion(bindClauses.map(\.variable))
        for subquery in subqueries {
            bound.formUnion(subquery.variables)
        }
        return bound
    }

    private func collectExpressionVariables() -> Set<Variable> {
        var sources: [String] = []
        sources.append(contentsOf: filters)
        sources.append(contentsOf: bindClauses.map(\.expression))
        sources.append(contentsOf: filterExpressions.map { $0.render() })
        sources.append(contentsOf: having)
        sources.append(contentsOf: orderBy.map(\.expression))
        return extractVariables(from: sources)
    }

    private func collectFreeExpressionVariables() -> Set<Variable> {
        collectExpressionVariables().subtracting(collectBoundVariables())
    }

    private func collectAllReferencedVariables() -> Set<Variable> {
        var references = collectBoundVariables().union(collectExpressionVariables())
        references.formUnion(groupBy)
        for subquery in subqueries {
            references.formUnion(subquery.collectAllReferencedVariables())
        }
        return references
    }
}

private func extractVariables(from fragments: [String]) -> Set<Variable> {
    var result: Set<Variable> = []
    let regex = try? NSRegularExpression(pattern: #"\?[A-Za-z_][A-Za-z0-9_\-]*"#)
    for fragment in fragments {
        let nsrange = NSRange(fragment.startIndex ..< fragment.endIndex, in: fragment)
        let matches = regex?.matches(in: fragment, options: [], range: nsrange) ?? []
        for match in matches {
            if let range = Range(match.range, in: fragment) {
                result.insert(Variable(rawValue: String(fragment[range])))
            }
        }
    }
    return result
}

public struct SPARQLAskQuery: Hashable, Sendable, SPARQLQueryRenderable {
    public var prefixes: [String: IRI]
    public var wherePatterns: [String]

    public init(
        prefixes: [String: IRI] = [:],
        wherePatterns: [String]
    ) {
        self.prefixes = prefixes
        self.wherePatterns = wherePatterns
    }

    public func render() -> String {
        var lines: [String] = []
        for key in prefixes.keys.sorted() {
            if let iri = prefixes[key] {
                lines.append("PREFIX \(key): <\(iri.rawValue)>")
            }
        }
        lines.append("ASK")
        lines.append("WHERE {")
        for pattern in wherePatterns {
            lines.append("  \(pattern)")
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }
}

public struct SPARQLConstructQuery: Hashable, Sendable, SPARQLQueryRenderable {
    public var prefixes: [String: IRI]
    public var constructPatterns: [String]
    public var wherePatterns: [String]
    public var limit: Int?

    public init(
        prefixes: [String: IRI] = [:],
        constructPatterns: [String],
        wherePatterns: [String],
        limit: Int? = nil
    ) {
        self.prefixes = prefixes
        self.constructPatterns = constructPatterns
        self.wherePatterns = wherePatterns
        self.limit = limit
    }

    public func render() -> String {
        var lines: [String] = []
        for key in prefixes.keys.sorted() {
            if let iri = prefixes[key] {
                lines.append("PREFIX \(key): <\(iri.rawValue)>")
            }
        }
        lines.append("CONSTRUCT {")
        for pattern in constructPatterns {
            lines.append("  \(pattern)")
        }
        lines.append("}")
        lines.append("WHERE {")
        for pattern in wherePatterns {
            lines.append("  \(pattern)")
        }
        lines.append("}")
        if let limit {
            lines.append("LIMIT \(limit)")
        }
        return lines.joined(separator: "\n")
    }
}

public struct SPARQLDescribeQuery: Hashable, Sendable, SPARQLQueryRenderable {
    public var prefixes: [String: IRI]
    public var variables: [Variable]
    public var iris: [IRI]
    public var wherePatterns: [String]
    public var limit: Int?

    public init(
        prefixes: [String: IRI] = [:],
        variables: [Variable] = [],
        iris: [IRI] = [],
        wherePatterns: [String] = [],
        limit: Int? = nil
    ) {
        self.prefixes = prefixes
        self.variables = variables
        self.iris = iris
        self.wherePatterns = wherePatterns
        self.limit = limit
    }

    public func render() -> String {
        var lines: [String] = []
        for key in prefixes.keys.sorted() {
            if let iri = prefixes[key] {
                lines.append("PREFIX \(key): <\(iri.rawValue)>")
            }
        }

        let described = (
            variables.map(\.sparql) + iris.map { "<\($0.rawValue)>" }
        ).joined(separator: " ")

        lines.append("DESCRIBE \(described.isEmpty ? "*" : described)")

        if !wherePatterns.isEmpty {
            lines.append("WHERE {")
            for pattern in wherePatterns {
                lines.append("  \(pattern)")
            }
            lines.append("}")
        }

        if let limit {
            lines.append("LIMIT \(limit)")
        }

        return lines.joined(separator: "\n")
    }
}

public enum SPARQLAccept: String, Sendable {
    case jsonResults = "application/sparql-results+json"
    case xmlResults = "application/sparql-results+xml"
    case csv = "text/csv"
    case tsv = "text/tab-separated-values"
}

public enum SPARQLGraphAccept: String, Sendable {
    case turtle = "text/turtle"
    case ntriples = "application/n-triples"
    case rdfXML = "application/rdf+xml"
    case jsonLD = "application/ld+json"
}
