import IRIKit
import RDFCore
import RDFFormats

/// An IRI term.
func iri(_ value: IRI) -> ObjectTerm {
    .iri(value)
}

/// A blank node term.
func blank(_ label: String) throws -> ObjectTerm {
    .blankNode(try BlankNode(label))
}

/// A literal term.
func literal(
    _ lexicalForm: String,
    language: String? = nil,
    direction: BaseDirection? = nil
) throws -> ObjectTerm {
    if let language {
        return .literal(try Literal(lexicalForm, languageTag: language, baseDirection: direction))
    }
    return .literal(Literal(lexicalForm))
}

/// The `xsd:integer` literal a Turtle document writes as the bare integer
/// `lexicalForm` (RDF 1.2 Turtle §2.5.2), decoded by RDFFormats'
/// ``TurtleDecoder``: the datatype comes from the decoder, not from an IRI
/// typed here.
func integer(_ lexicalForm: String) throws -> Literal {
    for triple in try TurtleDecoder().decode("[] a \(lexicalForm) .") {
        if case .literal(let literal) = triple.object { return literal }
    }
    throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "\(lexicalForm) is no Turtle integer."))
}

/// A triple term.
func triple(_ subject: IRI, _ predicate: IRI, _ object: ObjectTerm) -> ObjectTerm {
    .tripleTerm(Graph.Element(subject: .iri(subject), predicate: predicate, object: object))
}
