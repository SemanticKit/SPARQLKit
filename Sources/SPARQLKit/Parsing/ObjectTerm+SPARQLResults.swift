import Foundation
import IRIKit
import RDFCore
import RDFFormats

/// The terms a SPARQL results document carries.
///
/// This is where the IRIs a results document carries enter the runtime: each
/// is validated as an absolute IRI.
extension ObjectTerm {
    /// A TSV field (SPARQL 1.2 Query Results CSV and TSV Formats §4.1), which
    /// is one term in Turtle / N-Triples syntax.
    ///
    /// The field is read by RDFFormats' ``TurtleDecoder`` as the object of a
    /// triple term, `<c> <c> <<( <c> <c> FIELD )>> .`: that position admits
    /// exactly one term (RDF 1.2 Turtle `ttObject`), with no object list, no
    /// collection, no directive and no further statement. The carrier `<c>`
    /// is a fresh `urn:uuid:` IRI (RFC 9562), so no field text can name it to
    /// end the triple term and repeat the carrier statement, and the closing
    /// `)>> .` starts a new line, so no comment in the field can hide it. A
    /// TSV field writes a blank node as `_:label` (§4.1); an anonymous `[]`,
    /// which Turtle would turn into a fresh node, is rejected.
    init(tsv field: String) throws {
        let carrier = "<urn:uuid:" + UUID().uuidString.lowercased() + ">"
        let statement = carrier + " " + carrier + " <<( " + carrier + " " + carrier + " " + field + "\n)>> .\n"
        let read = { (document: String) throws -> Graph in
            do {
                return try TurtleDecoder().decode(document)
            } catch {
                throw SPARQLError.decodingFailure("TSV field \(field) is not a term: \(error)")
            }
        }
        guard let triple = try read(statement).only, case .tripleTerm(let carried) = triple.object else {
            throw SPARQLError.decodingFailure("TSV field \(field) is not a single term.")
        }
        let term = carried.object

        // Every blank node the field writes as `_:label` keeps its label when
        // the labels b1 … bN that the decoder would give anonymous nodes are
        // already written before the field. An anonymous node then gets a
        // label after bN, so its term differs.
        let count = term.blankNodeOccurrences
        if count > 0 {
            let claimed = (1 ... count).map { "_:b\($0)" }.joined(separator: " , ")
            let relabelled = try read(carrier + " " + carrier + " " + claimed + " .\n" + statement).compactMap { triple in
                if case .tripleTerm(let carried) = triple.object { return carried.object }
                return nil
            }
            guard relabelled == [term] else {
                throw SPARQLError.decodingFailure("TSV field \(field) writes a blank node that is not _:label.")
            }
        }
        self = term
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
        // RDF 1.2 Concepts §3.4: `xsd:string` is the datatype of a simple
        // literal, and `rdf:langString` and `rdf:dirLangString` need a
        // language tag. RDFFormats' term reading maps a datatype IRI to the
        // literal's form, so the typed literal is read back through it:
        // written by ``NTriplesEncoder`` as the object of a triple and read
        // by ``NTriplesDecoder``, which gives `^^xsd:string` as the simple
        // literal and refuses `^^rdf:langString` and `^^rdf:dirLangString`.
        let datatypeIRI = try IRI(resultText: datatype)
        let written: Graph = [Graph.Element(subject: .iri(datatypeIRI), predicate: datatypeIRI, object: .literal(Literal(lexicalForm, datatype: datatypeIRI)))]
        let read: Graph
        do {
            read = try NTriplesDecoder().decode(NTriplesEncoder().encode(written))
        } catch {
            throw SPARQLError.decodingFailure("\"\(lexicalForm)\"^^<\(datatype)> is not a literal: \(error)")
        }
        guard let triple = read.only, case .literal(let literal) = triple.object else {
            throw SPARQLError.decodingFailure("\"\(lexicalForm)\"^^<\(datatype)> is not a single literal.")
        }
        self = .literal(literal)
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

private extension Graph {
    /// The one triple of a graph that has exactly one.
    var only: Element? {
        count == 1 ? first : nil
    }
}

private extension ObjectTerm {
    /// How many times a blank node occurs in this term, through any triple
    /// terms it holds.
    var blankNodeOccurrences: Int {
        switch self {
        case .blankNode:
            return 1
        case .tripleTerm(let triple):
            let subject = if case .blankNode = triple.subject { 1 } else { 0 }
            return subject + triple.object.blankNodeOccurrences
        case .iri, .literal:
            return 0
        }
    }
}
