import Foundation
import SemanticKit
import RDFKit

public struct SPARQLGraphResultDecoder: Sendable {
    public init() {}

    public func decodeTurtle(_ data: Data) throws -> Graph {
        guard let turtle = String(data: data, encoding: .utf8) else {
            throw SPARQLError.decodingFailure("Graph result payload is not UTF-8 Turtle.")
        }

        do {
            return try Graph(turtle: turtle)
        } catch {
            throw SPARQLError.decodingFailure("Failed to parse Turtle graph result: \(error)")
        }
    }
}
