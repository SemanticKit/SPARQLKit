/// A media type for the results of a `SELECT` or `ASK` query
/// (SPARQL 1.2 Protocol §2.1.6).
public enum SPARQLAccept: String, Sendable, CaseIterable {
    case jsonResults = "application/sparql-results+json"
    case xmlResults = "application/sparql-results+xml"
    case csv = "text/csv"
    case tsv = "text/tab-separated-values"

    /// The format a service description names for this media type.
    public var format: any Formats.Format {
        switch self {
        case .jsonResults: Formats.SPARQL_Results_JSON
        case .xmlResults: Formats.SPARQL_Results_XML
        case .csv: Formats.SPARQL_Results_CSV
        case .tsv: Formats.SPARQL_Results_TSV
        }
    }
}
