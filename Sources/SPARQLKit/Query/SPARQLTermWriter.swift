import IRIKit
import RDFCore
import RDFFormats

/// Writes RDF terms in SPARQL syntax (SPARQL 1.2 Query Language §19.8).
///
/// This is where a term's IRI becomes query text: the translation into SPARQL,
/// and nowhere else.
struct SPARQLTermWriter {
    func write(_ variable: Variable) -> String {
        "?" + variable.name
    }

    func write(_ iri: IRI) -> String {
        "<" + iri.rawValue + ">"
    }

    func write(_ node: BlankNode) -> String {
        "_:" + node.identifier
    }

    /// A literal as `STRING_LITERAL_QUOTE` with its language tag, base
    /// direction or datatype.
    func write(_ literal: Literal) -> String {
        var text = quoted(literal.lexicalForm)
        if let language = literal.languageTag {
            text += "@" + language
            if let direction = literal.textDirection {
                text += "--" + direction.rawValue
            }
        } else if let datatype = literal.datatype {
            text += "^^" + write(datatype)
        }
        return text
    }

    /// A string as `STRING_LITERAL_QUOTE`, escaping what the grammar requires.
    func quoted(_ string: String) -> String {
        var text = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": text += #"\""#
            case "\\": text += #"\\"#
            case "\n": text += #"\n"#
            case "\r": text += #"\r"#
            case "\t": text += #"\t"#
            case "\u{08}": text += #"\b"#
            case "\u{0C}": text += #"\f"#
            default: text.unicodeScalars.append(scalar)
            }
        }
        return text + "\""
    }

    func write(_ subject: SubjectTerm) -> String {
        switch subject {
        case .iri(let iri): write(iri)
        case .blankNode(let node): write(node)
        }
    }

    func write(_ object: ObjectTerm) -> String {
        switch object {
        case .iri(let iri): write(iri)
        case .blankNode(let node): write(node)
        case .literal(let literal): write(literal)
        case .tripleTerm(let term):
            "<<( " + write(term.subject) + " " + write(term.predicate) + " " + write(term.object) + " )>>"
        }
    }

    /// A ground triple as a `TriplesTemplate` line.
    func write(_ triple: DecodedTriple) -> String {
        write(triple.subject) + " " + write(triple.predicate) + " " + write(triple.object) + " ."
    }
}

/// Collects the lines of a rendered query or update, indented by nesting.
struct SPARQLLines {
    private(set) var lines: [String] = []
    private var depth = 0

    mutating func append(_ line: String) {
        lines.append(String(repeating: "  ", count: depth) + line)
    }

    mutating func block(_ opening: String, _ body: (inout SPARQLLines) -> Void) {
        append(opening.isEmpty ? "{" : opening + " {")
        depth += 1
        body(&self)
        depth -= 1
        append("}")
    }

    var text: String {
        lines.joined(separator: "\n")
    }
}
