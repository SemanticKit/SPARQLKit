import Foundation
import IRIKit

/// The live endpoints the environment names, decoded at the boundary.
enum Environment {
    static let values = ProcessInfo.processInfo.environment

    static func url(_ name: String) -> URL? {
        values[name].flatMap(URL.init(string:))
    }

    static func iri(_ name: String) -> IRI? {
        values[name].flatMap(IRI.init(rawValue:))
    }

    static func iris(_ name: String) -> [IRI] {
        (values[name] ?? "")
            .split(separator: ",")
            .compactMap { IRI(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
    }

    static var queryURL: URL? { url("SPARQL_ENDPOINT_URL") }
    static var updateURL: URL? { url("SPARQL_UPDATE_ENDPOINT_URL") }
    static var graphStoreURL: URL? { url("SPARQL_GRAPH_STORE_URL") }
}
