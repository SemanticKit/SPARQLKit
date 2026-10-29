import Foundation
import Testing
@testable import SPARQLKit

@Test
func graphResultDecoderParsesTurtleGraph() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "construct_result_turtle", withExtension: "ttl"))
    let data = try Data(contentsOf: fixtureURL)

    let graph = try SPARQLGraphResultDecoder().decodeTurtle(data)

    #expect(graph.count == 2)
}

@Test
func graphResultDecoderRejectsInvalidPayload() {
    let invalid = Data("this is not turtle <<".utf8)

    do {
        _ = try SPARQLGraphResultDecoder().decodeTurtle(invalid)
        Issue.record("Expected invalid Turtle graph payload to fail decoding.")
    } catch let error as SPARQLError {
        if case .decodingFailure = error {
            #expect(Bool(true))
        } else {
            Issue.record("Expected decodingFailure but got: \(error)")
        }
    } catch {
        Issue.record("Unexpected non-SPARQLError: \(error)")
    }
}
