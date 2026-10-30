import IRIKit
import RDFCore
import RDFFormats
import RDFKit

/// The terms a SPARQL results document carries.
///
/// This is where the IRIs a results document carries enter the runtime: each
/// is validated as an absolute IRI.
extension ObjectTerm {
    /// A TSV field (SPARQL 1.2 Query Results CSV and TSV Formats §4.1), which
    /// is a term in Turtle / N-Triples syntax, read as the object of a
    /// one-triple Turtle document.
    init(tsv field: String) throws {
        let carrier = "<" + RDF.value.metadata.id.rawValue + ">"
        let triples: Graph
        do {
            triples = try TurtleDecoder().decode(carrier + " " + carrier + " " + field + " .")
        } catch {
            throw SPARQLError.decodingFailure("TSV field \(field) is not a term: \(error)")
        }
        guard triples.count == 1, let triple = triples.first else {
            throw SPARQLError.decodingFailure("TSV field \(field) is not a single term.")
        }
        self = triple.object
    }

    /// A CSV field (SPARQL 1.2 Query Results CSV and TSV Formats §3.1). CSV
    /// writes only a term's lexical form, so the field is a simple literal.
    init(csv field: String) {
        self = .literal(Literal(field))
    }

    /// An IRI from a JSON `uri` or XML `<uri>` value (SPARQL 1.2 Query Results
    /// JSON Format §3.2.2, XML Format §2.3).
    init(iri text: String) throws {
        self = .iri(try IRI(resultText: text))
    }

    /// A blank node from a JSON `bnode` or XML `<bnode>` label.
    init(blankNode label: String) throws {
        guard let node = try? BlankNode(label) else { throw SPARQLError.decodingFailure("A blank node needs a label.") }
        self = .blankNode(node)
    }

    /// A literal from its lexical form and the optional datatype, language
    /// tag and base direction the document gives it.
    ///
    /// RDF 1.2 Concepts §3.3: a literal is a language-tagged string exactly
    /// when it has a language tag; only a language-tagged string has a base
    /// direction; `xsd:string` is the datatype of a simple literal.
    init(literal lexicalForm: String, datatype: String?, language: String?, direction: String?) throws {
        if let language {
            guard !language.isEmpty else { throw SPARQLError.decodingFailure("A language tag cannot be empty.") }
            var baseDirection: BaseDirection?
            if let direction {
                guard let value = BaseDirection(rawValue: direction.lowercased()) else {
                    throw SPARQLError.decodingFailure("'\(direction)' is not a base direction.")
                }
                baseDirection = value
            }
            self = .literal(try Literal(lexicalForm, languageTag: language, baseDirection: baseDirection))
            return
        }
        guard direction == nil else {
            throw SPARQLError.decodingFailure("Only a language-tagged string has a base direction.")
        }
        guard let datatype else {
            self = .literal(Literal(lexicalForm))
            return
        }
        let datatypeIRI = try IRI(resultText: datatype)
        if datatypeIRI == XSD.string.metadata.id {
            self = .literal(Literal(lexicalForm))
            return
        }
        if datatypeIRI == RDF.langString.metadata.id || datatypeIRI == RDF.dirLangString.metadata.id {
            throw SPARQLError.decodingFailure("A language-tagged string needs a language tag.")
        }
        self = .literal(try Literal(lexicalForm, datatype: datatypeIRI))
    }

    /// A triple term from its three decoded components.
    init(tripleTermSubject subject: ObjectTerm, predicate: ObjectTerm, object: ObjectTerm) throws {
        guard let subject = subject.subject else {
            throw SPARQLError.decodingFailure("A triple term's subject must be an IRI or blank node.")
        }
        guard case .iri(let predicate) = predicate else {
            throw SPARQLError.decodingFailure("A triple term's predicate must be an IRI.")
        }
        self = .tripleTerm(Triple(subject: subject, predicate: predicate, object: object))
    }
}

extension IRI {
    /// An IRI a results document carries, validated as an absolute IRI.
    init(resultText text: String) throws {
        do {
            self = try IRI(validating: text)
        } catch {
            throw SPARQLError.decodingFailure("<\(text)> is not an absolute IRI.")
        }
    }
}
