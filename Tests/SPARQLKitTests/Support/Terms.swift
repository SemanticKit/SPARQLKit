import IRIKit
import RDFCore
import RDFFormats
import RDFKit

/// An IRI term.
func iri(_ value: IRI) -> ObjectTerm {
    .iri(value)
}

/// A blank node term.
func blank(_ label: String) -> ObjectTerm {
    .blankNode(BlankNode(rawValue: label))
}

/// A literal term.
func literal(
    _ lexicalForm: String,
    datatype: IRI? = nil,
    language: String? = nil,
    direction: TextDirection? = nil
) throws -> ObjectTerm {
    .literal(try Literal(lexicalForm, languageTag: language, textDirection: direction, datatype: datatype))
}

/// A triple term.
func triple(_ subject: IRI, _ predicate: IRI, _ object: ObjectTerm) -> ObjectTerm {
    .tripleTerm(TripleTermValue(subject: .iri(subject), predicate: predicate, object: object))
}

/// `xsd:integer`, at the boundary where decoded literals carry it.
let xsdInteger: IRI = XSD.integer.metadata.id
