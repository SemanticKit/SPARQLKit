import IRIKit
import RDFCore
import RDFFormats

/// A position in a triple pattern: a variable or an RDF term
/// (SPARQL 1.2 Query Language §18.1.3, `VarOrTerm`).
public indirect enum SPARQLPatternTerm: Hashable, Sendable {
    /// A query variable.
    case variable(Variable)

    /// A term declared in an `@Ontology`: a class, property, datatype or
    /// named individual, held as its generated type.
    case term(SPARQLTerm)

    /// A resource whose identity is external to the runtime, such as a
    /// resource in the endpoint's data that no ontology declares. Its IRI is
    /// the identity the endpoint dereferences.
    case iri(IRI)

    /// A blank node, which acts as a variable that is not projected.
    case blankNode(SPARQLBlankNode)

    /// A literal.
    case literal(Literal)

    /// A triple term pattern, `<<( s p o )>>` (SPARQL 1.2 Query Language §4.1.5).
    case tripleTerm(subject: SPARQLPatternTerm, predicate: SPARQLPatternTerm, object: SPARQLPatternTerm)

    /// The pattern position that matches exactly this decoded term.
    ///
    /// - Throws: ``SPARQLError/invalidRequest(_:)`` for a blank node, or a
    ///   triple term that holds one. A blank node in a results document or a
    ///   decoded graph is scoped to that document (SPARQL 1.2 Query Results
    ///   JSON Format §3.2.2, RDF 1.2 Concepts §3.5); written into a query it
    ///   would be a fresh non-distinguished variable (Query Language §4.1.4),
    ///   not the same term, so it cannot be matched exactly.
    public init(_ term: ObjectTerm) throws {
        switch term {
        case .iri(let iri):
            self = .iri(iri)
        case .blankNode:
            throw SPARQLError.invalidRequest("A decoded blank node cannot be matched by a query pattern.")
        case .literal(let literal):
            self = .literal(literal)
        case .tripleTerm(let triple):
            self = .tripleTerm(
                subject: try SPARQLPatternTerm(triple.subject.object),
                predicate: .iri(triple.predicate),
                object: try SPARQLPatternTerm(triple.object)
            )
        }
    }

    /// The variables this position mentions.
    public var variables: Set<Variable> {
        switch self {
        case .variable(let variable): [variable]
        case .term, .iri, .blankNode, .literal: []
        case .tripleTerm(let subject, let predicate, let object):
            subject.variables.union(predicate.variables).union(object.variables)
        }
    }

    /// Whether this position, or a triple term inside it, is a blank node.
    var containsBlankNode: Bool {
        switch self {
        case .blankNode: true
        case .variable, .term, .iri, .literal: false
        case .tripleTerm(let subject, let predicate, let object):
            subject.containsBlankNode || predicate.containsBlankNode || object.containsBlankNode
        }
    }

    func render() -> String {
        let writer = SPARQLTermWriter()
        switch self {
        case .variable(let variable): return writer.write(variable)
        case .term(let term): return writer.write(term)
        case .iri(let iri): return writer.write(iri)
        case .blankNode(let node): return writer.write(node)
        case .literal(let literal): return writer.write(literal)
        case .tripleTerm(let subject, let predicate, let object):
            return "<<( " + subject.render() + " " + predicate.render() + " " + object.render() + " )>>"
        }
    }
}
