import IRIKit
import RDF
import RDFCore
import RDFFormats

extension RDFCore.Graph {
    /// The objects of the triples a decoded document states about `subject`
    /// with the property `property`.
    ///
    /// The property is the translated individual of `rdf:Property` (such as
    /// `ServiceDescription.feature`); the IRI that denotes it is read here,
    /// where a decoder matches the document's triples.
    func objects(_ property: any RDFCore.Resource, of subject: SubjectTerm) -> [ObjectTerm] {
        compactMap { triple in
            triple.subject == subject && triple.predicate == IRI(of: property) ? triple.object : nil
        }
    }

    /// The first object of `property` on `subject`, for a property a
    /// document gives one value.
    func object(_ property: any RDFCore.Resource, of subject: SubjectTerm) -> ObjectTerm? {
        objects(property, of: subject).first
    }

    /// The nodes the document states have the property `property`.
    func subjects(_ property: any RDFCore.Resource) -> Set<SubjectTerm> {
        Set(compactMap { $0.predicate == IRI(of: property) ? $0.subject : nil })
    }

    /// The nodes the document states are members of `class` (`rdf:type`).
    func members(of class: any RDFCore.ResourceClass.Type) -> Set<SubjectTerm> {
        guard let classIRI = IRI(of: `class`) else { return [] }
        return Set(compactMap { triple in
            triple.predicate == IRI(of: RDF.type) && triple.object == .iri(classIRI) ? triple.subject : nil
        })
    }

    /// The IRIs among the objects of `property` on `subject`.
    func iris(_ property: any RDFCore.Resource, of subject: SubjectTerm) -> [IRI] {
        objects(property, of: subject).compactMap { object in
            if case .iri(let iri) = object { return iri }
            return nil
        }
    }

    /// The lexical forms of the literals among the objects of `property` on
    /// `subject`.
    func lexicalForms(_ property: any RDFCore.Resource, of subject: SubjectTerm) -> [String] {
        objects(property, of: subject).compactMap { object in
            if case .literal(let literal) = object { return literal.lexicalForm }
            return nil
        }
    }
}

extension SubjectTerm {
    /// The IRI that denotes the node, or `nil` for a blank node: what a
    /// decoder gives the individual it makes for the node.
    var iri: IRI? {
        if case .iri(let iri) = self { return iri }
        return nil
    }
}
