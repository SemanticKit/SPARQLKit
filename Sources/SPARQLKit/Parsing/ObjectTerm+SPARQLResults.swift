import IRIKit
import RDFCore
import RDFKit

/// The RDF terms a SPARQL results document writes, read into RDFCore's terms.
///
/// The JSON, XML, CSV and TSV results formats (SPARQL 1.2 Query Results JSON,
/// XML, CSV and TSV Formats) write each bound term as an IRI, a blank node
/// label, a literal with an optional datatype, language tag and base
/// direction, or a triple term. These are where that text enters the runtime.
extension ObjectTerm {
    /// An IRI written in a results document.
    init(iri text: String) throws {
        self = .iri(try IRI(validating: text))
    }

    /// A blank node written in a results document.
    init(blankNodeLabel label: String) throws {
        self = .blankNode(try BlankNode(label))
    }

    /// A literal written in a results document.
    ///
    /// A language tag makes a language-tagged string whatever datatype is
    /// written beside it; a base direction needs a language tag.
    init(
        literal lexicalForm: String,
        datatype: String? = nil,
        language: String? = nil,
        direction: BaseDirection? = nil
    ) throws {
        if let language {
            self = .literal(try Literal(lexicalForm, languageTag: language, baseDirection: direction))
        } else if direction != nil {
            throw SPARQLError.decodingFailure("A base direction needs a language tag.")
        } else if let datatype {
            self = .literal(try Literal(lexicalForm, datatype: try IRI(validating: datatype)))
        } else {
            self = .literal(Literal(lexicalForm))
        }
    }

    /// A triple term written in a results document.
    init(subject: ObjectTerm, predicate: ObjectTerm, object: ObjectTerm) throws {
        guard let subject = subject.subject else {
            throw SPARQLError.decodingFailure("A triple term subject must be an IRI or a blank node.")
        }
        guard case .iri(let predicate) = predicate else {
            throw SPARQLError.decodingFailure("A triple term predicate must be an IRI.")
        }
        self = .tripleTerm(Graph.Element(subject: subject, predicate: predicate, object: object))
    }
}

extension BaseDirection {
    /// A base direction written in a results document: the JSON and XML
    /// formats' `its:dir`, or what follows `--` in CSV and TSV. RDF 1.2
    /// Concepts §3.4 has two base directions, `ltr` and `rtl`; any other value
    /// would name a different term, so it is an error, not dropped.
    init(resultsText text: String) throws {
        guard let direction = BaseDirection(rawValue: text.lowercased()) else {
            throw SPARQLError.decodingFailure("'\(text)' is not a base direction: it must be ltr or rtl.")
        }
        self = direction
    }
}
