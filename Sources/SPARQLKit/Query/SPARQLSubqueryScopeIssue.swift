/// A variable an outer expression reads that a subquery binds but does not
/// project, so the outer query cannot see it (SPARQL 1.2 Query Language §12).
public struct SPARQLSubqueryScopeIssue: Hashable, Sendable {
    public let variable: Variable
    public let subqueryProjection: Set<Variable>

    public init(variable: Variable, subqueryProjection: Set<Variable>) {
        self.variable = variable
        self.subqueryProjection = subqueryProjection
    }
}
