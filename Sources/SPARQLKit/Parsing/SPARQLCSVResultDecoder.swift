import Foundation
import RDFCore

/// Decodes SPARQL 1.2 Query Results CSV documents.
///
/// CSV writes only the lexical form of a term (SPARQL 1.2 Query Results CSV
/// and TSV Formats §3.1), so each field is read by
/// ``RDFCore/ObjectTerm/init(csv:)`` as a simple literal: the format does not
/// say which kind of term it was.
public struct SPARQLCSVResultDecoder: Sendable {
    public init() {}

    /// Decodes a CSV results document. Every value is a simple literal.
    ///
    /// The document's records and fields are read as RFC 4180 writes them: a
    /// field may be quoted, a quote inside a quoted field is doubled, and a
    /// record ends at a line break outside quotes.
    public func decode(_ data: Data) throws -> SPARQLResultSet {
        guard let content = String(data: data, encoding: .utf8) else {
            throw SPARQLError.decodingFailure("CSV content is not UTF-8.")
        }
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
        return try SPARQLResultSet(delimitedRows: rows, term: ObjectTerm.init(csv:))
    }
}
