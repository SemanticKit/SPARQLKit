/// A query or update that SPARQLKit translates into SPARQL text.
///
/// Rendering is the one place SPARQL text exists: it is produced when a
/// request is sent to an endpoint, and nothing else in SPARQLKit builds or
/// reads query text.
public protocol SPARQLQueryRenderable: Sendable {
    /// The SPARQL text an endpoint receives.
    func render() -> String
}
