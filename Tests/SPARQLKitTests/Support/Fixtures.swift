import Foundation
import IRIKit
import RDFCore
import RDFFormats
import Testing

/// The bytes of a fixture file, by its file name.
func fixture(_ fileName: String) throws -> Data {
    let file = URL(fileURLWithPath: fileName)
    let url = try #require(
        Bundle.module.url(forResource: file.deletingPathExtension().lastPathComponent, withExtension: file.pathExtension)
    )
    return try Data(contentsOf: url)
}

/// The graph a Turtle fixture states, decoded by RDFFormats'
/// ``TurtleDecoder``.
func fixtureGraph(_ fileName: String) throws -> Graph {
    try TurtleDecoder().decode(String(decoding: try fixture(fileName), as: UTF8.self))
}

/// The one triple a Turtle fixture states.
func fixtureTriple(_ fileName: String) throws -> Graph.Element {
    let graph = try fixtureGraph(fileName)
    try #require(graph.count == 1, "\(fileName) states \(graph.count) triples, not one.")
    return try #require(graph.first)
}

/// The subject, predicate and object IRIs of the one triple a Turtle fixture
/// states: the terms come from the decoder, not from IRIs typed in Swift.
func fixtureIRIs(_ fileName: String) throws -> (subject: IRI, predicate: IRI, object: IRI) {
    let triple = try fixtureTriple(fileName)
    guard case .iri(let subject) = triple.subject, case .iri(let object) = triple.object else {
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "\(fileName) states no triple of three IRIs."))
    }
    return (subject, triple.predicate, object)
}
