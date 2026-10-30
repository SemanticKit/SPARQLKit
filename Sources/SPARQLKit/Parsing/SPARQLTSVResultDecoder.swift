import Foundation
import RDFCore

/// Decodes SPARQL 1.2 Query Results TSV documents.
///
/// TSV writes every term in its Turtle form (SPARQL 1.2 Query Results CSV and
/// TSV Formats §4.1), so each field is read by ``RDFCore/ObjectTerm/init(tsv:)``.
public struct SPARQLTSVResultDecoder: Sendable {
    public init() {}

    /// Decodes a TSV results document.
    public func decode(_ data: Data) throws -> SPARQLResultSet {
        guard let content = String(data: data, encoding: .utf8) else {
            throw SPARQLError.decodingFailure("TSV content is not UTF-8.")
        }
        // A record ends at a line feed (§4), and a carriage return before it
        // belongs to the line ending. No other line separator ends one: a
        // Turtle string may hold U+000B, U+000C, U+0085, U+2028 and U+2029
        // as they are, so a field may too.
        let rows = content.unicodeScalars
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { record in
                let line = record.last == "\r" ? record.dropLast() : record[...]
                return String(String.UnicodeScalarView(line))
                    .split(separator: "\t", omittingEmptySubsequences: false)
                    .map(String.init)
            }
        return try SPARQLResultSet(delimitedRows: rows, term: ObjectTerm.init(tsv:))
    }
}
