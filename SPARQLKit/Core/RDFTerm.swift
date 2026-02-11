import Foundation
import SemanticKit

public typealias IRI = SemanticKit.IRI
public typealias Literal = SemanticKit.Literal
public typealias BlankNode = SemanticKit.BlankNode
public typealias TextDirection = SemanticKit.TextDirection
public typealias RDFTripleTerm = SemanticKit.TripleTerm
public typealias RDFTerm = SemanticKit.AnyRDFObject
public typealias RDFSubject = SemanticKit.AnyRDFSubject
public typealias Triple = SemanticKit.Graph.TripleType

public struct Variable: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        if rawValue.hasPrefix("?") {
            self.rawValue = String(rawValue.dropFirst())
        } else {
            self.rawValue = rawValue
        }
    }

    public var sparql: String {
        "?\(rawValue)"
    }
}

public extension RDFTerm {
    var sparql: String {
        description
    }

    static func iri(_ iriString: String) throws -> Self {
        .init(try IRI(iriString))
    }

    static func blankNode(_ identifier: String) throws -> Self {
        .init(try BlankNode(identifier))
    }

    static func literal(
        _ value: String,
        datatype: String? = nil,
        language: String? = nil,
        direction: TextDirection? = nil
    ) throws -> Self {
        if let language {
            return .init(try Literal(value, languageTag: language, textDirection: direction))
        }
        if let datatype {
            return .init(try Literal(value, datatype: try IRI(datatype)))
        }
        return .init(try Literal(value, textDirection: direction))
    }
}

public typealias Binding = [Variable: RDFTerm]

public struct SPARQLResultSet: Hashable, Sendable {
    public let variables: [Variable]
    public let bindings: [Binding]
    public let version: String?

    public init(variables: [Variable], bindings: [Binding], version: String? = nil) {
        self.variables = variables
        self.bindings = bindings
        self.version = version
    }
}
