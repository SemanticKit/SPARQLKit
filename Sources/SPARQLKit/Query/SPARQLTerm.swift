import IRIKit
import RDFCore

/// A term declared in an `@Ontology`, in a position of a query or update.
///
/// The term is held as its generated Swift type: a property
/// (`Foaf.name.sparql`), the individual type of a class
/// (`Foaf.PersonIndividual.sparql`), a datatype (`XSD.integer.sparql`) or a
/// named individual (`SPARQLTerm(Fauna.carnivore)`). Two terms are equal when
/// they are the same type. The term's IRI is its type's static
/// ``RDFCore/Entity/metadata``, read only when ``SPARQLTermWriter`` writes
/// the query text.
public struct SPARQLTerm: Hashable, Sendable {
    private let entity: any RDFCore.Entity.Type

    init(entity: any RDFCore.Entity.Type) {
        self.entity = entity
    }

    /// The term a named individual is: the `Individual` declaration its type
    /// was generated from.
    public init(_ individual: some RDFCore.Resource) {
        self.init(entity: type(of: individual))
    }

    /// The IRI SPARQL text names the term by. Read only by the writer.
    var iri: IRI {
        entity.metadata.id
    }

    public static func == (lhs: SPARQLTerm, rhs: SPARQLTerm) -> Bool {
        ObjectIdentifier(lhs.entity) == ObjectIdentifier(rhs.entity)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(entity))
    }
}

extension RDFCore.Entity {
    /// This generated term, in a position of a SPARQL query or update.
    public static var sparql: SPARQLTerm {
        SPARQLTerm(entity: self)
    }
}
