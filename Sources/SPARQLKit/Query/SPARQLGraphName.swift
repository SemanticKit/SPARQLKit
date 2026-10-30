import IRIKit

/// The name in a `GRAPH` pattern: an IRI or a variable
/// (SPARQL 1.2 Query Language §19.8, `GraphGraphPattern ::= 'GRAPH' VarOrIri
/// GroupGraphPattern`).
public enum SPARQLGraphName: Hashable, Sendable {
    /// A named graph of the endpoint's dataset.
    case iri(IRI)
    /// A variable that ranges over the dataset's graph names.
    case variable(Variable)

    /// The variables this name mentions.
    public var variables: Set<Variable> {
        if case .variable(let variable) = self { return [variable] }
        return []
    }

    func render() -> String {
        switch self {
        case .iri(let iri): SPARQLTermWriter().write(iri)
        case .variable(let variable): SPARQLTermWriter().write(variable)
        }
    }
}
