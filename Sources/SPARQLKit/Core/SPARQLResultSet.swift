import Foundation
import RDFCore

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

/// One solution of a SELECT query: the RDF term bound to each variable.
public typealias Binding = [Variable: ObjectTerm]

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
