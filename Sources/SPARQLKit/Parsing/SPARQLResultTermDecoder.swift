import IRIKit
import RDFCore
import RDFFormats
import RDFKit

/// Turns the parts of a term in a JSON or XML results document into a
/// decoded term (SPARQL 1.2 Query Results JSON Format §3.2.2, XML Format §2.3).
///
/// This is where the IRIs a results document carries enter the runtime: each
/// is validated as an absolute IRI.
struct SPARQLResultTermDecoder {
    func iri(_ text: String) throws -> ObjectTerm {
        .iri(try decodeIRI(text))
    }

    func blankNode(_ label: String) throws -> ObjectTerm {
        guard !label.isEmpty else { throw SPARQLError.decodingFailure("A blank node needs a label.") }
        return .blankNode(BlankNode(rawValue: label))
    }

    /// A literal from its lexical form and the optional datatype, language
    /// tag and base direction the document gives it.
    ///
    /// RDF 1.2 Concepts §3.3: a literal is a language-tagged string exactly
    /// when it has a language tag; only a language-tagged string has a base
    /// direction; `xsd:string` is the datatype of a simple literal.
    func literal(_ lexicalForm: String, datatype: String?, language: String?, direction: String?) throws -> ObjectTerm {
        if let language {
            guard !language.isEmpty else { throw SPARQLError.decodingFailure("A language tag cannot be empty.") }
            var textDirection: TextDirection?
            if let direction {
                guard let value = TextDirection(rawValue: direction.lowercased()) else {
                    throw SPARQLError.decodingFailure("'\(direction)' is not a base direction.")
                }
                textDirection = value
            }
            return .literal(try Literal(lexicalForm, languageTag: language, textDirection: textDirection))
        }
        guard direction == nil else {
            throw SPARQLError.decodingFailure("Only a language-tagged string has a base direction.")
        }
        guard let datatype else { return .literal(try Literal(lexicalForm)) }
        let datatypeIRI = try decodeIRI(datatype)
        if datatypeIRI == XSD.string.metadata.id {
            return .literal(try Literal(lexicalForm))
        }
        if datatypeIRI == RDF.langString.metadata.id || datatypeIRI == RDF.dirLangString.metadata.id {
            throw SPARQLError.decodingFailure("A language-tagged string needs a language tag.")
        }
        return .literal(try Literal(lexicalForm, datatype: datatypeIRI))
    }

    /// A triple term from its three decoded components.
    func triple(subject: ObjectTerm, predicate: ObjectTerm, object: ObjectTerm) throws -> ObjectTerm {
        guard let subject = subject.subject else {
            throw SPARQLError.decodingFailure("A triple term's subject must be an IRI or blank node.")
        }
        guard case .iri(let predicate) = predicate else {
            throw SPARQLError.decodingFailure("A triple term's predicate must be an IRI.")
        }
        return .tripleTerm(TripleTermValue(subject: subject, predicate: predicate, object: object))
    }

    private func decodeIRI(_ text: String) throws -> IRI {
        do {
            return try IRI(validating: text)
        } catch {
            throw SPARQLError.decodingFailure("<\(text)> is not an absolute IRI.")
        }
    }
}
