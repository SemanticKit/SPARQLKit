/// The predicate position of a triple pattern: a variable, a property or a
/// property path (SPARQL 1.2 Query Language §19.8, `VerbPath` and `VerbSimple`).
public enum SPARQLVerb: Hashable, Sendable {
    /// A query variable.
    case variable(Variable)
    /// `a`, the keyword for `rdf:type` (SPARQL 1.2 Query Language §4.2.4).
    case a
    /// A property declared in an `@Ontology`, such as `Foaf.name.sparql`.
    case property(SPARQLTerm)
    /// A property path.
    case path(SPARQLPropertyPath)

    /// The variables this position mentions.
    public var variables: Set<Variable> {
        if case .variable(let variable) = self { return [variable] }
        return []
    }

    /// Whether this verb is a property path rather than a single predicate.
    var isPath: Bool {
        if case .path = self { return true }
        return false
    }

    func render() -> String {
        switch self {
        case .variable(let variable): SPARQLTermWriter().write(variable)
        case .a: "a"
        case .property(let property): SPARQLTermWriter().write(property)
        case .path(let path): path.render()
        }
    }
}
