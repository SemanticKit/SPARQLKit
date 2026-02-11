import Testing
@testable import SPARQLKit

@Test
func rdfTermEqualityAndHashAreStableForSameSemanticValue() throws {
    let a = try RDFTerm.literal("chat", language: "fr", direction: .ltr)
    let b = try RDFTerm.literal("chat", language: "fr", direction: .ltr)

    #expect(a == b)
    #expect(a.hashValue == b.hashValue)

    let set: Set<RDFTerm> = [a, b]
    #expect(set.count == 1)
}

@Test
func rdfTermEqualityDistinguishesDirectionalLiteralVariants() throws {
    let ltr = try RDFTerm.literal("chat", language: "fr", direction: .ltr)
    let rtl = try RDFTerm.literal("chat", language: "fr", direction: .rtl)
    let noDirection = try RDFTerm.literal("chat", language: "fr")

    #expect(ltr != rtl)
    #expect(ltr != noDirection)
    #expect(rtl != noDirection)
}

@Test
func rdfTripleTermEqualityAndHashAreStable() throws {
    let t1 = RDFTerm(
        RDFTripleTerm(
            subject: try RDFSubject(try IRI("http://example.org/s")),
            predicate: try IRI("http://example.org/p"),
            object: try RDFTerm.literal("o")
        )
    )
    let t2 = RDFTerm(
        RDFTripleTerm(
            subject: try RDFSubject(try IRI("http://example.org/s")),
            predicate: try IRI("http://example.org/p"),
            object: try RDFTerm.literal("o")
        )
    )

    #expect(t1 == t2)
    #expect(t1.hashValue == t2.hashValue)

    let set: Set<RDFTerm> = [t1, t2]
    #expect(set.count == 1)
}

@Test
func rdfTermFactoriesValidateMalformedInput() {
    #expect(throws: Error.self) {
        _ = try RDFTerm.iri("")
    }

    #expect(throws: Error.self) {
        _ = try RDFTerm.blankNode("")
    }

    #expect(throws: Error.self) {
        _ = try RDFTerm.literal("hello", language: "")
    }

    #expect(throws: Error.self) {
        _ = try RDFTerm.literal("hello", direction: .ltr)
    }

    #expect(throws: Error.self) {
        _ = try RDFTerm.literal("hello", datatype: "relative/type")
    }
}
