import Testing

extension Tag {
    /// Typed queries and updates rendered to SPARQL text.
    @Tag static var rendering: Self
    /// Results and graphs decoded from what an endpoint returns.
    @Tag static var decoding: Self
    /// SPARQL Protocol and Graph Store Protocol requests.
    @Tag static var `protocol`: Self
    /// Manifest-driven conformance cases.
    @Tag static var conformance: Self
    /// Vocabularies declared with the DSL.
    @Tag static var vocabulary: Self
}
