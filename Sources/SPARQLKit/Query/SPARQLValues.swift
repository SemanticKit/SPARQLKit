import RDFFormats

/// Inline data, `VALUES` (SPARQL 1.2 Query Language §10.2).
///
/// Each row holds one entry per variable; `nil` is `UNDEF`.
public struct SPARQLValues: Hashable, Sendable {
    public let variables: [Variable]
    public let rows: [[ObjectTerm?]]

    public init(variables: [Variable], rows: [[ObjectTerm?]]) {
        self.variables = variables
        self.rows = rows
    }

    func render(into lines: inout SPARQLLines) {
        let writer = SPARQLTermWriter()
        func cell(_ term: ObjectTerm?) -> String { term.map(writer.write) ?? "UNDEF" }
        if variables.count == 1 {
            lines.block("VALUES " + writer.write(variables[0])) { lines in
                for row in rows { lines.append(cell(row.first ?? nil)) }
            }
            return
        }
        lines.block("VALUES (" + variables.map(writer.write).joined(separator: " ") + ")") { lines in
            for row in rows { lines.append("(" + row.map(cell).joined(separator: " ") + ")") }
        }
    }
}
