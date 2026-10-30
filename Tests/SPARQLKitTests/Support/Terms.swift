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
    datatype: IRI? = nil,
    language: String? = nil,
    direction: BaseDirection? = nil
) throws -> ObjectTerm {
    if let language {
        return .literal(try Literal(lexicalForm, languageTag: language, baseDirection: direction))
    }
    if let datatype {
        return .literal(try Literal(lexicalForm, datatype: datatype))
    }
    return .literal(Literal(lexicalForm))
}

/// A triple term.
func triple(_ subject: IRI, _ predicate: IRI, _ object: ObjectTerm) -> ObjectTerm {
    .tripleTerm(Graph.Element(subject: .iri(subject), predicate: predicate, object: object))
}

/// The datatype IRI `xsd:integer`, as decoded literals carry it.
let xsdInteger: IRI = "http://www.w3.org/2001/XMLSchema#integer"
