import Foundation

public enum SPARQLError: Error, Equatable, Sendable {
    case missingEndpoint
    case invalidResponse
    case invalidRequest(String)
    case httpStatus(Int, body: String)
    case decodingFailure(String)
}
