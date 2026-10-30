/// One entry of a `SELECT` clause (SPARQL 1.2 Query Language §18.2.4.1).
public enum SPARQLProjection: Hashable, Sendable, ExpressibleByStringLiteral {
    /// A projected variable.
    case variable(Variable)
    /// `(expression AS ?variable)`
    case expression(SPARQLExpression, as: Variable)

    public init(stringLiteral value: String) {
        self = .variable(Variable(stringLiteral: value))
    }

    /// The variable this entry projects.
    public var variable: Variable {
        switch self {
        case .variable(let variable), .expression(_, let variable): variable
        }
    }

    func render() -> String {
        switch self {
        case .variable(let variable):
            variable.render()
        case .expression(let expression, let variable):
            "(" + expression.render() + " AS " + variable.render() + ")"
        }
    }
}
