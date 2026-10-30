import IRIKit

/// A `SELECT` query (SPARQL 1.2 Query Language §16.1).
public struct SPARQLSelectQuery: SPARQLResultsQuery, Hashable {
    /// The `SELECT` clause; empty is `SELECT *`.
    public var projection: [SPARQLProjection]
    public var distinct: Bool
    public var reduced: Bool
    /// The `FROM` graphs of the dataset clause.
    public var fromGraphs: [IRI]
    /// The `FROM NAMED` graphs of the dataset clause.
    public var fromNamedGraphs: [IRI]
    /// The `WHERE` group graph pattern.
    public var patterns: [SPARQLPattern]
    public var groupBy: [Variable]
    public var having: [SPARQLExpression]
    public var orderBy: [SPARQLOrderCondition]
    public var limit: UInt?
    public var offset: UInt?

    public init(
        _ projection: [SPARQLProjection] = [],
        distinct: Bool = false,
        reduced: Bool = false,
        fromGraphs: [IRI] = [],
        fromNamedGraphs: [IRI] = [],
        where patterns: [SPARQLPattern],
        groupBy: [Variable] = [],
        having: [SPARQLExpression] = [],
        orderBy: [SPARQLOrderCondition] = [],
        limit: UInt? = nil,
        offset: UInt? = nil
    ) {
        self.projection = projection
        self.distinct = distinct
        self.reduced = reduced
        self.fromGraphs = fromGraphs
        self.fromNamedGraphs = fromNamedGraphs
        self.patterns = patterns
        self.groupBy = groupBy
        self.having = having
        self.orderBy = orderBy
        self.limit = limit
        self.offset = offset
    }

    /// The variables the query projects; for `SELECT *`, every variable its
    /// pattern can bind.
    public var projectedVariables: Set<Variable> {
        projection.isEmpty ? SPARQLPattern.boundVariables(of: patterns) : Set(projection.map(\.variable))
    }

    /// The query as a SPARQL 1.2 `SelectQuery` (§19.8 [7]): `SelectClause`,
    /// `DatasetClause*`, `WhereClause` and `SolutionModifier`.
    public func render() -> String {
        var lines = SPARQLLines()
        renderSelectClause(into: &lines)
        for graph in fromGraphs { lines.append("FROM " + graph.render()) }
        for graph in fromNamedGraphs { lines.append("FROM NAMED " + graph.render()) }
        renderWhereClauseAndModifiers(into: &lines)
        return lines.text
    }

    /// The query as a SPARQL 1.2 `SubSelect` (§19.8 [8]), which has no
    /// dataset clause.
    func renderSubSelect(into lines: inout SPARQLLines) {
        renderSelectClause(into: &lines)
        renderWhereClauseAndModifiers(into: &lines)
    }

    func renderSelectClause(into lines: inout SPARQLLines) {
        var select = "SELECT"
        if distinct {
            select += " DISTINCT"
        } else if reduced {
            select += " REDUCED"
        }
        select += projection.isEmpty ? " *" : " " + projection.map { $0.render() }.joined(separator: " ")
        lines.append(select)
    }

    func renderWhereClauseAndModifiers(into lines: inout SPARQLLines) {
        lines.block("WHERE") { SPARQLPattern.render(patterns, into: &$0) }
        if !groupBy.isEmpty {
            lines.append("GROUP BY " + groupBy.map { $0.render() }.joined(separator: " "))
        }
        if !having.isEmpty {
            lines.append("HAVING " + having.map { "(" + $0.render() + ")" }.joined(separator: " "))
        }
        if !orderBy.isEmpty {
            lines.append("ORDER BY " + orderBy.map { $0.render() }.joined(separator: " "))
        }
        if let limit { lines.append("LIMIT \(limit)") }
        if let offset { lines.append("OFFSET \(offset)") }
    }

    /// The variables outer expressions read that a subquery binds without
    /// projecting them, here and in every nested subquery.
    public func validateSubqueryScopes() -> [SPARQLSubqueryScopeIssue] {
        var issues: Set<SPARQLSubqueryScopeIssue> = []
        let freeVariables = expressionVariables.subtracting(SPARQLPattern.boundVariables(of: patterns))
        for subquery in patterns.flatMap(\.subqueries) {
            let projected = subquery.projectedVariables
            let hidden = subquery.referencedVariables.subtracting(projected)
            for variable in freeVariables.intersection(hidden) {
                issues.insert(SPARQLSubqueryScopeIssue(variable: variable, subqueryProjection: projected))
            }
            issues.formUnion(subquery.validateSubqueryScopes())
        }
        return issues.sorted { $0.variable < $1.variable }
    }

    /// How the query's variables are shared between its local patterns and
    /// its `SERVICE` patterns.
    public func federatedBindingAnalysis() -> SPARQLFederatedBindingAnalysis {
        var local: Set<Variable> = []
        var services: [SPARQLFederatedBindingAnalysis.Service] = []
        func visit(_ patterns: [SPARQLPattern]) {
            for pattern in patterns {
                switch pattern {
                case .service(let endpoint, _, let inner):
                    services.append(.init(endpoint: endpoint, variables: SPARQLPattern.boundVariables(of: inner)))
                case .group(let inner), .optional(let inner), .minus(let inner):
                    visit(inner)
                case .graph(let name, let inner):
                    local.formUnion(name.variables)
                    visit(inner)
                case .union(let branches):
                    branches.forEach(visit)
                default:
                    local.formUnion(pattern.boundVariables)
                }
            }
        }
        visit(patterns)
        let remote = services.reduce(into: Set<Variable>()) { $0.formUnion($1.variables) }
        return SPARQLFederatedBindingAnalysis(
            localVariables: local,
            services: services,
            propagatedVariables: local.intersection(remote),
            serviceOnlyVariables: remote.subtracting(local)
        )
    }

    /// The variables the query's expressions read.
    private var expressionVariables: Set<Variable> {
        var variables = SPARQLPattern.expressionVariables(of: patterns)
        for entry in projection {
            if case .expression(let expression, _) = entry { variables.formUnion(expression.variables) }
        }
        for condition in having { variables.formUnion(condition.variables) }
        for condition in orderBy { variables.formUnion(condition.expression.variables) }
        return variables
    }

    /// Every variable the query mentions, in its own scope and its subqueries'.
    private var referencedVariables: Set<Variable> {
        var variables = SPARQLPattern.boundVariables(of: patterns).union(expressionVariables)
        variables.formUnion(groupBy)
        for subquery in patterns.flatMap(\.subqueries) {
            variables.formUnion(subquery.referencedVariables)
        }
        return variables
    }
}
