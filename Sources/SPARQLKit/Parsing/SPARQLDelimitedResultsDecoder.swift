import Foundation
import RDFCore
import RDFFormats
import RDFKit

/// Decodes SPARQL 1.2 Query Results CSV and TSV documents.
///
/// TSV writes every term in its Turtle form (SPARQL 1.2 Query Results CSV and
/// TSV Formats §4.1), so each TSV field is read by RDFFormats'
/// ``TurtleDecoder``. CSV writes only the lexical form of a term (§3.1), so a
/// CSV field is a simple literal: the format does not say which kind of term
/// it was.
public struct SPARQLDelimitedResultsDecoder: Sendable {
    public init() {}

    /// Decodes a CSV results document. Every value is a simple literal.
    public func decodeCSV(_ data: Data) throws -> SPARQLResultSet {
        guard let content = String(data: data, encoding: .utf8) else {
            throw SPARQLError.decodingFailure("CSV content is not UTF-8.")
        }
        return try decodeRows(try parseCSV(content)) { .literal(try Literal($0)) }
    }

    /// Decodes a TSV results document.
    public func decodeTSV(_ data: Data) throws -> SPARQLResultSet {
        guard let content = String(data: data, encoding: .utf8) else {
            throw SPARQLError.decodingFailure("TSV content is not UTF-8.")
        }
        let rows = content
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
        return try decodeRows(rows, decodeTSVTerm)
    }

    private func decodeRows(
        _ rows: [[String]],
        _ decodeTerm: (String) throws -> ObjectTerm
    ) throws -> SPARQLResultSet {
        guard let header = rows.first, !header.allSatisfy(\.isEmpty) else {
            throw SPARQLError.decodingFailure("Missing header row.")
        }
        let variables = try header.map(SPARQLResultTermDecoder().variable)
        var bindings: [Binding] = []
        for row in rows.dropFirst() where !row.allSatisfy(\.isEmpty) {
            var binding: Binding = [:]
            for (variable, field) in zip(variables, row) where !field.isEmpty {
                binding[variable] = try decodeTerm(field)
            }
            bindings.append(binding)
        }
        return SPARQLResultSet(variables: variables, bindings: bindings)
    }

    /// A TSV field, which is a term in Turtle syntax, read as the object of a
    /// one-triple Turtle document.
    private func decodeTSVTerm(_ field: String) throws -> ObjectTerm {
        let carrier = "<" + RDF.value.metadata.id.rawValue + ">"
        let triples: [DecodedTriple]
        do {
            triples = try TurtleDecoder().decode(carrier + " " + carrier + " " + field + " .")
        } catch {
            throw SPARQLError.decodingFailure("TSV field \(field) is not a term: \(error)")
        }
        guard triples.count == 1, let triple = triples.first else {
            throw SPARQLError.decodingFailure("TSV field \(field) is not a single term.")
        }
        return triple.object
    }

    private func parseCSV(_ content: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var cell = ""
        var inQuotes = false
        var iterator = content.makeIterator()

        func endCell() {
            row.append(cell)
            cell = ""
        }
        func endRow() {
            endCell()
            rows.append(row)
            row = []
        }
        func plain(_ character: Character) {
            switch character {
            case ",": endCell()
            case "\n", "\r\n": endRow()
            case "\r": break
            default: cell.append(character)
            }
        }

        while let character = iterator.next() {
            if character == "\"" {
                guard inQuotes else {
                    inQuotes = true
                    continue
                }
                guard let next = iterator.next() else {
                    inQuotes = false
                    break
                }
                if next == "\"" {
                    cell.append("\"")
                } else {
                    inQuotes = false
                    plain(next)
                }
            } else if inQuotes {
                cell.append(character)
            } else {
                plain(character)
            }
        }
        if inQuotes {
            throw SPARQLError.decodingFailure("Unterminated quoted CSV value.")
        }
        if !cell.isEmpty || !row.isEmpty {
            endRow()
        }
        return rows
    }
}
