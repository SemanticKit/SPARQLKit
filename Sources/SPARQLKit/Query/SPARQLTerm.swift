import IRIKit
import RDFCore
import RDFFormats

/// A translated term in a position of a query or update.
///
/// The term is the Swift the vocabulary was translated into: an individual,
/// such as the format `Formats.Turtle`, a property's term type, such as
/// `FOAF.name`, or a class, such as `FOAF.PersonIndividual`. Two terms are
/// equal when they are the same individual (`===`), the same property term
/// type or the same class. The IRI that denotes the term is read only when
/// the term is rendered into query text, the translation into SPARQL.
public struct SPARQLTerm: Hashable, Sendable {
    private enum Denotation: Sendable {
        case individual(any RDFCore.Resource)
        case property(any RDFCore.PropertyTerm.Type)
        case `class`(any RDFCore.ResourceClass.Type)
    }

    private let denotation: Denotation

    /// The term an individual is.
    ///
    /// - Precondition: The individual is denoted by an IRI. A query names a
    ///   resource only by its IRI; a blank node written into a query is a
    ///   fresh variable (SPARQL 1.2 Query Language §4.1.4), not the resource.
    public init(_ individual: any RDFCore.Resource) {
        precondition(IRI(of: individual) != nil, "A blank node has no IRI a query can name it by.")
        denotation = .individual(individual)
    }

    /// The term a property is, as its translated term type.
    ///
    /// - Precondition: The property's declared key gives an IRI.
    public init(_ property: any RDFCore.PropertyTerm.Type) {
        precondition(IRI(of: property) != nil, "The property's declared key gives no IRI a query can name it by.")
        denotation = .property(property)
    }

    /// The term a class is, as the Swift class whose instances are its
    /// members.
    ///
    /// - Precondition: The class is denoted by an IRI.
    public init(_ class: any RDFCore.ResourceClass.Type) {
        precondition(IRI(of: `class`) != nil, "A blank node has no IRI a query can name it by.")
        denotation = .class(`class`)
    }

    /// The IRI that denotes this term, derived when the term leaves the
    /// runtime.
    private var iri: IRI? {
        switch denotation {
        case .individual(let individual): IRI(of: individual)
        case .property(let property): IRI(of: property)
        case .class(let type): IRI(of: type)
        }
    }

    /// This term in SPARQL text: the IRI that denotes it, as an `IRIREF`.
    func render() -> String {
        iri!.render()
    }

    /// Whether `iri` denotes this term: how a decoded result term is
    /// compared with it.
    func isDenoted(by iri: IRI) -> Bool {
        self.iri == iri
    }

    public static func == (lhs: SPARQLTerm, rhs: SPARQLTerm) -> Bool {
        lhs.identity == rhs.identity
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identity)
    }

    /// The Swift identity of the term: the object, the property term type,
    /// or the class.
    private var identity: ObjectIdentifier {
        switch denotation {
        case .individual(let individual): ObjectIdentifier(individual)
        case .property(let property): ObjectIdentifier(property)
        case .class(let type): ObjectIdentifier(type)
        }
    }
}

extension RDFCore.Resource {
    /// This individual, in a position of a SPARQL query or update.
    public var sparql: SPARQLTerm {
        SPARQLTerm(self)
    }
}

extension RDFCore.PropertyTerm {
    /// This property, in a position of a SPARQL query or update.
    public static var sparql: SPARQLTerm {
        SPARQLTerm(self)
    }
}

extension RDFCore.ResourceClass {
    /// This class, in a position of a SPARQL query or update.
    public static var sparql: SPARQLTerm {
        SPARQLTerm(self)
    }
}
