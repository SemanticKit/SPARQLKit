import IRIKit
import RDFCore
import RDFFormats

/// A translated term in a position of a query or update.
///
/// The term is the Swift the vocabulary was translated into: an individual,
/// such as the property `FOAF.name` or the format `Formats.Turtle`, or a
/// class, such as `FOAF.PersonIndividual`. Two terms are equal when they are
/// the same individual (`===`) or the same class. The IRI that denotes the
/// term is read only when the term is rendered into query text, the
/// translation into SPARQL.
public struct SPARQLTerm: Hashable, Sendable {
    private enum Denotation: Sendable {
        case individual(any RDFCore.Resource)
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

    /// The term a class is, as the Swift class whose instances are its
    /// members.
    ///
    /// - Precondition: The class is denoted by an IRI.
    public init(_ class: any RDFCore.ResourceClass.Type) {
        precondition(IRI(of: `class`) != nil, "A blank node has no IRI a query can name it by.")
        denotation = .class(`class`)
    }

    /// This term in SPARQL text: the IRI that denotes it, as an `IRIREF`.
    func render() -> String {
        switch denotation {
        case .individual(let individual): IRI(of: individual)!.render()
        case .class(let type): IRI(of: type)!.render()
        }
    }

    /// Whether `iri` denotes this term: how a decoded result term is
    /// compared with it.
    func isDenoted(by iri: IRI) -> Bool {
        switch denotation {
        case .individual(let individual): IRI(of: individual) == iri
        case .class(let type): IRI(of: type) == iri
        }
    }

    public static func == (lhs: SPARQLTerm, rhs: SPARQLTerm) -> Bool {
        lhs.identity == rhs.identity
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identity)
    }

    /// The Swift identity of the term: the object, or the class.
    private var identity: ObjectIdentifier {
        switch denotation {
        case .individual(let individual): ObjectIdentifier(individual)
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

extension RDFCore.ResourceClass {
    /// This class, in a position of a SPARQL query or update.
    public static var sparql: SPARQLTerm {
        SPARQLTerm(self)
    }
}
