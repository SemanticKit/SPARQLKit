import IRIKit
import RDFCore
import RDFFormats

/// A position in a triple pattern: a variable or an RDF term
/// (SPARQL 1.2 Query Language §18.1.3, `VarOrTerm`).
public indirect enum SPARQLPatternTerm: Hashable, Sendable {
    /// A query variable.
    case variable(Variable)

    /// An IRI.
    case iri(IRI)

    /// A blank node, which acts as a variable that is not projected.
    case blankNode(BlankNode)

    /// A literal.
    case literal(Literal)

    /// A triple term pattern, `<<( s p o )>>` (SPARQL 1.2 Query Language §4.1.5).
    case tripleTerm(subject: SPARQLPatternTerm, predicate: SPARQLPatternTerm, object: SPARQLPatternTerm)

    /// The pattern position that matches exactly this decoded term.
    public init(_ term: ObjectTerm) {
        switch term {
        case .iri(let iri): self = .iri(iri)
        case .blankNode(let node): self = .blankNode(node)
        case .literal(let literal): self = .literal(literal)
        case .tripleTerm(let triple):
            self = .tripleTerm(
                subject: SPARQLPatternTerm(triple.subject.object),
                predicate: .iri(triple.predicate),
                object: SPARQLPatternTerm(triple.object)
            )
        }
    }

    /// The variables this position mentions.
    public var variables: Set<Variable> {
        switch self {
        case .variable(let variable): [variable]
        case .iri, .blankNode, .literal: []
        case .tripleTerm(let subject, let predicate, let object):
            subject.variables.union(predicate.variables).union(object.variables)
        }
    }

    func render() -> String {
        let writer = SPARQLTermWriter()
        switch self {
        case .variable(let variable): return writer.write(variable)
        case .iri(let iri): return writer.write(iri)
        case .blankNode(let node): return writer.write(node)
        case .literal(let literal): return writer.write(literal)
        case .tripleTerm(let subject, let predicate, let object):
            return "<<( " + subject.render() + " " + predicate.render() + " " + object.render() + " )>>"
        }
    }
}
