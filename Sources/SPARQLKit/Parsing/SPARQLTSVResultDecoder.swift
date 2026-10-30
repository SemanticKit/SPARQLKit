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
        let rows = content
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
        return try SPARQLResultSet(delimitedRows: rows, term: ObjectTerm.init(tsv:))
    }
}
