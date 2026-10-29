import Foundation
import IRIKit

public enum SPARQLValueFormatter {
    public static func iri(_ value: String) throws -> String {
        let iri = try IRI(validating: value)
        return "<\(iri.rawValue)>"
    }

    public static func literal(
        _ value: String,
        language: String? = nil,
        datatype: String? = nil
    ) throws -> String {
        let escaped = escapeLiteral(value)
        if let language {
            return "\"\(escaped)\"@\(language)"
        }
        if let datatype {
            let datatypeIRI = try IRI(validating: datatype)
            return "\"\(escaped)\"^^<\(datatypeIRI.rawValue)>"
        }
        return "\"\(escaped)\""
    }

    private static func escapeLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}
