import IRIKit

/// The predicate position of a triple pattern: a variable, an IRI or a
/// property path (SPARQL 1.2 Query Language §19.8, `VerbPath` and `VerbSimple`).
public enum SPARQLVerb: Hashable, Sendable {
    /// A query variable.
    case variable(Variable)
    /// A predicate IRI.
    case iri(IRI)
    /// A property path.
    case path(SPARQLPropertyPath)

    /// The variables this position mentions.
    public var variables: Set<Variable> {
        if case .variable(let variable) = self { return [variable] }
        return []
    }

    func render() -> String {
        switch self {
        case .variable(let variable): SPARQLTermWriter().write(variable)
        case .iri(let iri): SPARQLTermWriter().write(iri)
        case .path(let path): path.render()
        }
    }
}
