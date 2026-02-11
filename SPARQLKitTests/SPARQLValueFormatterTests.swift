import Testing
@testable import SPARQLKit

@Test
func valueFormatterEscapesLiteralContent() throws {
    let rendered = try SPARQLValueFormatter.literal("quote=\" and slash=\\ and newline=\n")
    #expect(rendered == "\"quote=\\\" and slash=\\\\ and newline=\\n\"")
}

@Test
func valueFormatterSupportsTypedAndLanguageLiterals() throws {
    let typed = try SPARQLValueFormatter.literal(
        "42",
        datatype: "http://www.w3.org/2001/XMLSchema#integer"
    )
    let language = try SPARQLValueFormatter.literal("bonjour", language: "fr")

    #expect(typed == "\"42\"^^<http://www.w3.org/2001/XMLSchema#integer>")
    #expect(language == "\"bonjour\"@fr")
}

@Test
func valueFormatterRendersValidatedIRI() throws {
    let rendered = try SPARQLValueFormatter.iri("http://example.org/safe")
    #expect(rendered == "<http://example.org/safe>")
}

@Test
func valueFormatterPreservesUnicodeLiteralContent() throws {
    let rendered = try SPARQLValueFormatter.literal("naive cafe - cafe \u{00E9}")
    #expect(rendered == "\"naive cafe - cafe \u{00E9}\"")
}
