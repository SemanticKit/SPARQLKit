import RDFCore
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

    /// The solutions of a CSV or TSV results document, already split into
    /// records and fields (SPARQL 1.2 Query Results CSV and TSV Formats §2):
    /// the first record names the variables, and an empty field is an
    /// unbound variable. `term` reads one field in the format's term syntax.
    init(delimitedRows rows: [[String]], term: (String) throws -> ObjectTerm) throws {
        guard let header = rows.first, !header.allSatisfy(\.isEmpty) else {
            throw SPARQLError.decodingFailure("Missing header row.")
        }
        let variables = try header.map(Variable.init(resultName:))
        var bindings: [Binding] = []
        for row in rows.dropFirst() where !row.allSatisfy(\.isEmpty) {
            var binding: Binding = [:]
            for (variable, field) in zip(variables, row) where !field.isEmpty {
                binding[variable] = try term(field)
            }
            bindings.append(binding)
        }
        self.init(variables: variables, bindings: bindings)
    }
}

extension Dictionary where Key == Variable, Value == ObjectTerm {
    /// The declared individual among `candidates` that the IRI bound to
    /// `variable` names, decoded into its generated type.
    ///
    ///     let diet = binding.individual("diet", among: [Fauna.carnivore, Fauna.herbivore])
    ///
    /// Returns `nil` when the variable is unbound, is bound to something other
    /// than an IRI, or names none of the candidates.
    public func individual<Individual>(_ variable: Variable, among candidates: [Individual]) -> Individual? {
        guard case .iri(let iri)? = self[variable] else { return nil }
        return candidates.individual(named: iri)
    }

    /// Whether the IRI bound to `variable` names this declared term.
    public func binds(_ variable: Variable, to term: SPARQLTerm) -> Bool {
        guard case .iri(let iri)? = self[variable] else { return false }
        return iri == term.iri
    }
}
