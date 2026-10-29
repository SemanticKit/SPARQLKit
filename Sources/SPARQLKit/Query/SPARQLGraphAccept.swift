/// A media type for the graph a `CONSTRUCT` or `DESCRIBE` query returns, or
/// the Graph Store Protocol exchanges (SPARQL 1.2 Protocol §2.1.6).
public enum SPARQLGraphAccept: String, Sendable, CaseIterable {
    case turtle = "text/turtle"
    case ntriples = "application/n-triples"
    case rdfXML = "application/rdf+xml"
    case jsonLD = "application/ld+json"

    /// The format a service description names for this media type.
    public var format: any Formats.Format {
        switch self {
        case .turtle: Formats.Turtle
        case .ntriples: Formats.N_Triples
        case .rdfXML: Formats.RDF_XML
        case .jsonLD: Formats.JSON_LD
        }
    }
}
