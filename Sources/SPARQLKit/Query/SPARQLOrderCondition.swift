/// One key of an `ORDER BY` clause (SPARQL 1.2 Query Language §15.1).
public struct SPARQLOrderCondition: Hashable, Sendable {
    public let expression: SPARQLExpression
    public let ascending: Bool

    public init(_ expression: SPARQLExpression, ascending: Bool = true) {
        self.expression = expression
        self.ascending = ascending
    }

    func render() -> String {
        (ascending ? "ASC(" : "DESC(") + expression.render() + ")"
    }
}
