import Testing
@testable import SPARQLKit

@Suite("Media types", .tags(.protocol))
struct MediaTypeTests {
    @Test("A parameter is read by name, case-insensitively, without its quotes")
    func readsQuotedParameter() {
        let type = MediaType(#"Application/SPARQL-Results+JSON; Charset=utf-8; VERSION="1.2""#)

        #expect(type.essence == "application/sparql-results+json")
        #expect(type[parameter: "version"] == "1.2")
        #expect(type[parameter: "charset"] == "utf-8")
    }

    @Test("A missing, empty or malformed parameter has no value", arguments: [
        "application/sparql-results+json",
        "application/sparql-results+json; version=",
        #"application/sparql-results+json; version="""#,
        "application/sparql-results+json; version",
    ])
    func missingParameter(header: String) {
        #expect(MediaType(header)[parameter: "version"] == nil)
    }

    @Test("The first non-empty value of a repeated parameter is its value")
    func firstNonEmptyValue() {
        #expect(MediaType("text/plain; version=; version=1.1; version=1.2")[parameter: "version"] == "1.1")
    }
}
