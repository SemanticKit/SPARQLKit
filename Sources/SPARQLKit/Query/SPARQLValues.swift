/// Inline data, `VALUES` (SPARQL 1.2 Query Language §10.2).
///
/// Each row holds one entry per variable; `nil` is `UNDEF`. An entry is a
/// `DataBlockValue` (§19.8): a declared term, an IRI, a literal or a triple
/// term of those, never a variable or a blank node.
public struct SPARQLValues: Hashable, Sendable {
    public let variables: [Variable]
    public let rows: [[SPARQLPatternTerm?]]

    /// - Throws: ``SPARQLError/invalidRequest(_:)`` when a row does not hold
    ///   one entry per variable, or an entry is a variable or a blank node.
    public init(variables: [Variable], rows: [[SPARQLPatternTerm?]]) throws {
        for row in rows {
            guard row.count == variables.count else {
                throw SPARQLError.invalidRequest(
                    "A VALUES row has \(row.count) entries for \(variables.count) variables."
                )
            }
            for case let entry? in row where !entry.variables.isEmpty || entry.containsBlankNode {
                throw SPARQLError.invalidRequest("A VALUES entry must be a term, not a variable or a blank node.")
            }
        }
        self.variables = variables
        self.rows = rows
    }

    func render(into lines: inout SPARQLLines) {
        func cell(_ term: SPARQLPatternTerm?) -> String { term?.render() ?? "UNDEF" }
        if variables.count == 1 {
            lines.block("VALUES " + variables[0].render()) { lines in
                for row in rows { lines.append(cell(row[0])) }
            }
            return
        }
        lines.block("VALUES (" + variables.map { $0.render() }.joined(separator: " ") + ")") { lines in
            for row in rows { lines.append("(" + row.map(cell).joined(separator: " ") + ")") }
        }
    }
}
