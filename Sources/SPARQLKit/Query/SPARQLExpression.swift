import IRIKit
import RDFCore

/// A SPARQL expression (SPARQL 1.2 Query Language §17).
public indirect enum SPARQLExpression: Hashable, Sendable {
    /// A variable.
    case variable(Variable)
    /// A translated term: an individual or a class of a vocabulary.
    case term(SPARQLTerm)
    /// A resource whose identity is external to the runtime, named by its IRI.
    case iri(IRI)
    /// A literal.
    case literal(Literal)
    /// A unary operator applied to an operand.
    case unary(SPARQLUnaryOperator, SPARQLExpression)
    /// A binary operator applied to two operands.
    case binary(SPARQLExpression, SPARQLBinaryOperator, SPARQLExpression)
    /// `expression IN (list)`
    case `in`(SPARQLExpression, [SPARQLExpression])
    /// `expression NOT IN (list)`
    case notIn(SPARQLExpression, [SPARQLExpression])
    /// A built-in call such as `STRLEN(?name)` (§17.4).
    case builtIn(SPARQLBuiltInFunction, [SPARQLExpression])
    /// A call to a function a translated term names (§17.5, §17.6).
    case function(SPARQLTerm, [SPARQLExpression])
    /// An aggregate over a group (§18.5.1). `COUNT` with no operand is `COUNT(*)`.
    case aggregate(SPARQLAggregate, distinct: Bool, SPARQLExpression?)
    /// `EXISTS { pattern }` (§8.1.1).
    case exists([SPARQLPattern])
    /// `NOT EXISTS { pattern }` (§8.1.1).
    case notExists([SPARQLPattern])

    /// The variables the expression mentions, including those of `EXISTS`
    /// patterns.
    public var variables: Set<Variable> {
        switch self {
        case .variable(let variable):
            [variable]
        case .term, .iri, .literal:
            []
        case .unary(_, let operand):
            operand.variables
        case .binary(let lhs, _, let rhs):
            lhs.variables.union(rhs.variables)
        case .in(let operand, let list), .notIn(let operand, let list):
            list.reduce(operand.variables) { $0.union($1.variables) }
        case .builtIn(_, let arguments), .function(_, let arguments):
            arguments.reduce(into: []) { $0.formUnion($1.variables) }
        case .aggregate(_, _, let operand):
            operand?.variables ?? []
        case .exists(let patterns), .notExists(let patterns):
            patterns.reduce(into: []) { $0.formUnion($1.boundVariables.union($1.expressionVariables)) }
        }
    }

    func render() -> String {
        switch self {
        case .variable(let variable):
            return variable.render()
        case .term(let term):
            return term.render()
        case .iri(let iri):
            return iri.render()
        case .literal(let literal):
            return literal.render()
        case .unary(let op, let operand):
            return op.rawValue + "(" + operand.render() + ")"
        case .binary(let lhs, let op, let rhs):
            return "(" + lhs.render() + " " + op.rawValue + " " + rhs.render() + ")"
        case .in(let operand, let list):
            return "(" + operand.render() + " IN (" + list.map { $0.render() }.joined(separator: ", ") + "))"
        case .notIn(let operand, let list):
            return "(" + operand.render() + " NOT IN (" + list.map { $0.render() }.joined(separator: ", ") + "))"
        case .builtIn(let function, let arguments):
            return function.rawValue + "(" + arguments.map { $0.render() }.joined(separator: ", ") + ")"
        case .function(let function, let arguments):
            return function.render() + "(" + arguments.map { $0.render() }.joined(separator: ", ") + ")"
        case .aggregate(let aggregate, let distinct, let operand):
            var text = aggregate.keyword + "("
            if distinct { text += "DISTINCT " }
            text += operand?.render() ?? "*"
            if case .groupConcat(let separator?) = aggregate {
                text += "; SEPARATOR=" + Literal(separator).render()
            }
            return text + ")"
        case .exists(let patterns):
            return "EXISTS { " + SPARQLPattern.renderInline(patterns) + " }"
        case .notExists(let patterns):
            return "NOT EXISTS { " + SPARQLPattern.renderInline(patterns) + " }"
        }
    }
}

/// A unary operator (SPARQL 1.2 Query Language §17.3).
public enum SPARQLUnaryOperator: String, Hashable, Sendable {
    case logicalNot = "!"
    case unaryPlus = "+"
    case unaryMinus = "-"
}

/// A binary operator (SPARQL 1.2 Query Language §17.3).
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
