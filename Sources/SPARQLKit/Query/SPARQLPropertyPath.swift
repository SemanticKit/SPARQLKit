/// A property path (SPARQL 1.2 Query Language §9).
public indirect enum SPARQLPropertyPath: Hashable, Sendable {
    /// A path of length one through a translated property.
    case property(SPARQLTerm)
    /// `^path`
    case inverse(SPARQLPropertyPath)
    /// `path1 / path2`
    case sequence([SPARQLPropertyPath])
    /// `path1 | path2`
    case alternative([SPARQLPropertyPath])
    /// `path*`
    case zeroOrMore(SPARQLPropertyPath)
    /// `path+`
    case oneOrMore(SPARQLPropertyPath)
    /// `path?`
    case zeroOrOne(SPARQLPropertyPath)
    /// `!(iri1 | ^iri2)`: any predicate except those listed.
    case negated([SPARQLNegatedPathMember])

    func render() -> String {
        switch self {
        case .property(let property):
            return property.render()
        case .inverse(let path):
            return "^" + path.renderUnaryOperand()
        case .sequence(let parts):
            return parts.map { $0.renderSequenceOperand() }.joined(separator: "/")
        case .alternative(let parts):
            return parts.map { $0.renderSequenceOperand() }.joined(separator: "|")
        case .zeroOrMore(let path):
            return path.renderUnaryOperand() + "*"
        case .oneOrMore(let path):
            return path.renderUnaryOperand() + "+"
        case .zeroOrOne(let path):
            return path.renderUnaryOperand() + "?"
        case .negated(let members):
            let rendered = members.map { $0.render() }
            return rendered.count == 1 ? "!" + rendered[0] : "!(" + rendered.joined(separator: "|") + ")"
        }
    }

    private func renderUnaryOperand() -> String {
        switch self {
        case .property, .negated: render()
        default: "(" + render() + ")"
        }
    }

    private func renderSequenceOperand() -> String {
        switch self {
        case .property, .inverse, .zeroOrMore, .oneOrMore, .zeroOrOne, .negated: render()
        case .sequence, .alternative: "(" + render() + ")"
        }
    }
}

/// A member of a negated property set (SPARQL 1.2 Query Language §9.1,
/// `PathOneInPropertySet`).
public enum SPARQLNegatedPathMember: Hashable, Sendable {
    /// A forward property.
    case property(SPARQLTerm)
    /// An inverse property, `^property`.
    case inverse(SPARQLTerm)

    func render() -> String {
        switch self {
        case .property(let property): property.render()
        case .inverse(let property): "^" + property.render()
        }
    }
}
