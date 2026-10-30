import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import RDFCore
import RDFFormats

/// Decodes SPARQL 1.2 Query Results XML documents.
///
/// Each term in the document is read by an ``RDFCore/ObjectTerm``
/// initializer as its element closes (SPARQL 1.2 Query Results XML Format
/// §2.3).
public struct SPARQLXMLResultDecoder: Sendable {
    public init() {}

    /// Decodes a results document: the solutions of a `SELECT` query or the
    /// answer to an `ASK` query.
    public func decode(_ data: Data) throws -> SPARQLQueryResult {
        let parserDelegate = XMLResultsParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate

        let ok = parser.parse()
        if !ok {
            if let decodeError = parserDelegate.decodeError {
                throw decodeError
            }
            let message = parser.parserError?.localizedDescription ?? "Unknown XML parse error."
            throw SPARQLError.decodingFailure(message)
        }

        if let decodeError = parserDelegate.decodeError {
            throw decodeError
        }

        return try parserDelegate.makeResult()
    }

    /// Decodes the solutions of a `SELECT` query.
    ///
    /// - Throws: ``SPARQLError/decodingFailure(_:)`` when the document is
    ///   the answer to an `ASK` query.
    public func decode(_ data: Data) throws -> SPARQLResultSet {
        switch try decode(data) as SPARQLQueryResult {
        case let .bindings(resultSet):
            return resultSet
        case .boolean:
            throw SPARQLError.decodingFailure("Expected bindings payload, found boolean ASK result.")
        }
    }
}

private enum XMLTermKind {
    case uri
    case bnode
    case literal
    case triple
}

private struct XMLPartialTerm {
    let kind: XMLTermKind
    var text: String = ""
    var datatype: String?
    var language: String?
    var direction: String?
    var subject: ObjectTerm?
    var predicate: ObjectTerm?
    var object: ObjectTerm?
}

private final class XMLResultsParserDelegate: NSObject, XMLParserDelegate {
    private var variables: [Variable] = []
    private var bindings: [Binding] = []
    private var currentBinding: Binding = [:]

    private var currentBindingName: String?
    private var termStack: [XMLPartialTerm] = []
    private var tripleComponentStack: [String] = []

    private var booleanValue: Bool?
    private var hasResults = false
    private var inBoolean = false
    private var booleanTextBuffer = ""

    fileprivate var decodeError: SPARQLError?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = localName(elementName)

        switch name {
        case "variable":
            if let variableName = attributeDict["name"] {
                do {
                    variables.append(try Variable(resultName: variableName))
                } catch {
                    fail(parser, "'\(variableName)' is not a SPARQL variable name.")
                }
            }

        case "result":
            currentBinding = [:]
            hasResults = true

        case "binding":
            currentBindingName = attributeDict["name"]

        case "subject", "predicate", "object":
            tripleComponentStack.append(name)

        case "uri":
            termStack.append(XMLPartialTerm(kind: .uri))

        case "bnode":
            termStack.append(XMLPartialTerm(kind: .bnode))

        case "literal":
            termStack.append(XMLPartialTerm(
                kind: .literal,
                datatype: attributeDict["datatype"],
                language: attributeDict["xml:lang"] ?? attributeDict["lang"],
                direction: attributeDict["its:dir"] ?? attributeDict["dir"]
            ))

        case "triple":
            termStack.append(XMLPartialTerm(kind: .triple))

        case "boolean":
            inBoolean = true
            booleanTextBuffer = ""

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inBoolean {
            booleanTextBuffer.append(string)
            return
        }

        guard var top = termStack.last else {
            return
        }

        switch top.kind {
        case .uri, .bnode, .literal:
            top.text.append(string)
            termStack[termStack.count - 1] = top
        case .triple:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = localName(elementName)

        switch name {
        case "uri", "bnode", "literal":
            guard let partial = termStack.popLast() else {
                fail(parser, "Malformed XML result term stack.")
                return
            }
            guard partial.kind != .triple else {
                fail(parser, "Invalid XML parser state for leaf term finalization.")
                return
            }

            do {
                let term = try ObjectTerm(partial)
                try attachTerm(term, parser: parser)
            } catch let error as SPARQLError {
                if case let .decodingFailure(message) = error {
                    fail(parser, message)
                } else {
                    fail(parser, "Failed to decode XML result term.")
                }
            } catch {
                fail(parser, error.localizedDescription)
            }

        case "triple":
            guard let partial = termStack.popLast() else {
                fail(parser, "Malformed XML result triple term stack.")
                return
            }
            guard partial.kind == .triple else {
                fail(parser, "Incomplete triple term in XML results payload.")
                return
            }

            do {
                let term = try ObjectTerm(partial)
                try attachTerm(term, parser: parser)
            } catch let error as SPARQLError {
                if case let .decodingFailure(message) = error {
                    fail(parser, message)
                } else {
                    fail(parser, "Failed to decode XML result triple term.")
                }
            } catch {
                fail(parser, error.localizedDescription)
            }

        case "subject", "predicate", "object":
            _ = tripleComponentStack.popLast()

        case "binding":
            currentBindingName = nil

        case "result":
            bindings.append(currentBinding)
            currentBinding = [:]

        case "boolean":
            let trimmed = booleanTextBuffer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if trimmed == "true" {
                booleanValue = true
            } else if trimmed == "false" {
                booleanValue = false
            } else {
                // XML Format §2.3.3: the element holds `true` or `false`.
                fail(parser, "<boolean> holds '\(trimmed)', not true or false.")
            }
            inBoolean = false
            booleanTextBuffer = ""

        default:
            break
        }
    }

    func makeResult() throws -> SPARQLQueryResult {
        if let booleanValue {
            if hasResults {
                throw SPARQLError.decodingFailure("Invalid mixed XML result payload.")
            }
            return .boolean(booleanValue)
        }

        return .bindings(SPARQLResultSet(variables: variables, bindings: bindings))
    }

    private func attachTerm(_ term: ObjectTerm, parser _: XMLParser) throws {
        if var parent = termStack.last, parent.kind == .triple {
            guard let component = tripleComponentStack.last else {
                throw SPARQLError.decodingFailure("Malformed triple term structure in XML results.")
            }

            switch component {
            case "subject":
                parent.subject = term
            case "predicate":
                parent.predicate = term
            case "object":
                parent.object = term
            default:
                throw SPARQLError.decodingFailure("Unexpected triple component: \(component)")
            }

            termStack[termStack.count - 1] = parent
            return
        }

        guard let variableName = currentBindingName else {
            throw SPARQLError.decodingFailure("Term appeared outside of a binding in XML results.")
        }

        currentBinding[try Variable(resultName: variableName)] = term
    }

    private func fail(_ parser: XMLParser, _ message: String) {
        decodeError = .decodingFailure(message)
        parser.abortParsing()
    }

    private func localName(_ name: String) -> String {
        if let index = name.lastIndex(of: ":") {
            return String(name[name.index(after: index)...])
        }
        return name
    }
}

extension ObjectTerm {
    /// A term element of an XML results document, once it has closed:
    /// `<uri>`, `<bnode>`, `<literal>` or a `<triple>` whose three
    /// components have been read (SPARQL 1.2 Query Results XML Format §2.3).
    fileprivate init(_ partial: XMLPartialTerm) throws {
        switch partial.kind {
        case .uri:
            try self.init(iri: partial.text)
        case .bnode:
            try self.init(blankNode: partial.text)
        case .literal:
            try self.init(
                literal: partial.text,
                datatype: partial.datatype,
                language: partial.language,
                direction: partial.direction
            )
        case .triple:
            guard let subject = partial.subject,
                  let predicate = partial.predicate,
                  let object = partial.object
            else {
                throw SPARQLError.decodingFailure("Incomplete triple term in XML results payload.")
            }
            try self.init(tripleTermSubject: subject, predicate: predicate, object: object)
        }
    }
}
