/// A SPARQL query variable (SPARQL 1.2 Query Language §4.1.3).
///
/// The name is written without its `?` or `$` marker; ``init(_:)`` drops
/// either marker when given one.
public struct Variable: Hashable, Comparable, Sendable, Codable, ExpressibleByStringLiteral {
    /// The variable name, without `?` or `$`.
    public let name: String

    /// Creates a variable from its name.
    public init(_ name: String) {
        if let first = name.first, first == "?" || first == "$" {
            self.name = String(name.dropFirst())
        } else {
            self.name = name
        }
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public static func < (lhs: Variable, rhs: Variable) -> Bool {
        lhs.name < rhs.name
    }
}
