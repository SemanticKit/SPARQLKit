import Formats

/// A media type for the graph a `CONSTRUCT` or `DESCRIBE` query returns, or
/// the Graph Store Protocol exchanges (SPARQL 1.2 Protocol §2.1.6).
///
/// These are the RDF formats RDFFormats decodes, so every graph a client
/// asks for in one of them can be read back.
public enum SPARQLGraphAccept: String, Sendable, CaseIterable {
    case turtle = "text/turtle"
    case ntriples = "application/n-triples"

    /// The format a service description names for this media type.
    public var format: any Formats.Format {
        switch self {
        case .turtle: Formats.Turtle
        case .ntriples: Formats.`N-Triples`
        }
    }
}
