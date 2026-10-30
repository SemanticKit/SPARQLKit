/// A SPARQL query variable (SPARQL 1.2 Query Language §4.1.3).
///
/// The name is written without its `?` or `$` marker. It must match the
/// grammar's `VARNAME` (§19.8), so a variable always renders as one token:
/// a name taken from a results document header or from user input that is
/// not a `VARNAME` is rejected, never written into a query.
public struct Variable: Hashable, Comparable, Sendable, Codable, ExpressibleByStringLiteral {
    /// The variable name, without `?` or `$`.
    public let name: String

    /// Creates a variable from its name, dropping a leading `?` or `$`.
    ///
    /// - Throws: ``SPARQLError/invalidRequest(_:)`` when the name is not a
    ///   `VARNAME`.
    public init(_ name: String) throws {
        var name = Substring(name)
        if let first = name.first, first == "?" || first == "$" {
            name = name.dropFirst()
        }
        guard Self.isVarName(name) else {
            throw SPARQLError.invalidRequest("'\(name)' is not a SPARQL variable name (VARNAME).")
        }
        self.name = String(name)
    }

    /// A variable named in a results document's header or binding.
    ///
    /// A name that is not a `VARNAME` (§19.8) is rejected here, so no results
    /// document can put text into a later query through a variable.
    ///
    /// - Throws: ``SPARQLError/decodingFailure(_:)`` when the name is not a
    ///   `VARNAME`.
    init(resultName name: String) throws {
        do {
            try self.init(name)
        } catch {
            throw SPARQLError.decodingFailure("'\(name)' is not a SPARQL variable name.")
        }
    }

    /// A variable written in source. An invalid name is a programming error.
    public init(stringLiteral value: String) {
        do {
            try self.init(value)
        } catch {
            preconditionFailure("'\(value)' is not a SPARQL variable name (VARNAME).")
        }
    }

    public init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        do {
            try self.init(text)
        } catch {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "'\(text)' is not a SPARQL variable name (VARNAME)."
            ))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }

    /// This variable in SPARQL text, `?name` (§19.8, `VAR1`).
    func render() -> String {
        "?" + name
    }

    public static func < (lhs: Variable, rhs: Variable) -> Bool {
        lhs.name < rhs.name
    }

    /// `VARNAME ::= ( PN_CHARS_U | [0-9] ) ( PN_CHARS_U | [0-9] | #x00B7 |
    /// [#x0300-#x036F] | [#x203F-#x2040] )*`
    static func isVarName(_ name: Substring) -> Bool {
        guard let first = name.unicodeScalars.first, first.isSPARQLNameStart || first.isSPARQLDigit else {
            return false
        }
        return name.unicodeScalars.dropFirst().allSatisfy(\.isSPARQLVarNameCharacter)
    }
}
