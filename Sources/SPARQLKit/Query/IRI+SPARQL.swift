import IRIKit

extension IRI {
    /// This IRI as an `IRIREF` in SPARQL text (SPARQL 1.2 Query Language
    /// §19.8).
    ///
    /// This is where an IRI becomes query text: the translation into SPARQL,
    /// and nowhere else.
    func render() -> String {
        "<" + rawValue + ">"
    }
}
