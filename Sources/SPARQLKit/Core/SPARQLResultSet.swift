import RDFFormats

/// One solution of a query: the term each bound variable is bound to.
///
/// An unbound variable has no entry (SPARQL 1.2 Query Language §18.1.8).
public typealias Binding = [Variable: ObjectTerm]

/// The solution sequence of a `SELECT` query, as an endpoint returned it.
public struct SPARQLResultSet: Hashable, Sendable {
    /// The projected variables, in the order the results declare them.
    public let variables: [Variable]

    /// The solutions, in the order the results list them.
    public let bindings: [Binding]

    /// The version the results document announced, if any.
    public let version: String?

    public init(variables: [Variable], bindings: [Binding], version: String? = nil) {
        self.variables = variables
        self.bindings = bindings
        self.version = version
    }
}
