import Foundation
import IRIKit
import RDFCore

public enum SPARQLQueryResult: Hashable, Sendable {
    case bindings(SPARQLResultSet)
    case boolean(Bool)
}

public struct SPARQLDecodedQueryResult: Hashable, Sendable {
    public let result: SPARQLQueryResult
    public let version: String?

    public init(result: SPARQLQueryResult, version: String?) {
        self.result = result
        self.version = version
    }
}

public struct SPARQLJSONResultDecoder: Sendable {
    public init() {}

    public func decodeQueryResultWithMetadata(
        _ data: Data,
        contentType: String? = nil
    ) throws -> SPARQLDecodedQueryResult {
        do {
            let response = try JSONDecoder().decode(JSONResultResponse.self, from: data)
            let announcedVersion = response.version ?? versionParameter(from: contentType)

            if let boolean = response.boolean {
                guard response.results == nil else {
                    throw SPARQLError.decodingFailure("Invalid mixed JSON result payload.")
                }
                return SPARQLDecodedQueryResult(result: .boolean(boolean), version: announcedVersion)
            }

            guard let head = response.head, let results = response.results else {
                throw SPARQLError.decodingFailure("Missing head/results in JSON bindings payload.")
            }

            let variables = head.vars.map(Variable.init(rawValue:))
            let bindings = try results.bindings.map { row in
                try row.reduce(into: Binding()) { partial, entry in
                    partial[Variable(rawValue: entry.key)] = try entry.value.asTerm
                }
            }
            let resultSet = SPARQLResultSet(variables: variables, bindings: bindings, version: announcedVersion)
            return SPARQLDecodedQueryResult(result: .bindings(resultSet), version: announcedVersion)
        } catch let error as SPARQLError {
            throw error
        } catch {
            throw SPARQLError.decodingFailure(error.localizedDescription)
        }
    }

    public func decodeQueryResult(_ data: Data) throws -> SPARQLQueryResult {
        try decodeQueryResultWithMetadata(data).result
    }

    public func decode(_ data: Data) throws -> SPARQLResultSet {
        let queryResult = try decodeQueryResult(data)
        switch queryResult {
        case let .bindings(resultSet):
            return resultSet
        case .boolean:
            throw SPARQLError.decodingFailure("Expected bindings payload, found boolean ASK result.")
        }
    }
}

private extension SPARQLJSONResultDecoder {
    func versionParameter(from contentType: String?) -> String? {
        guard let contentType else {
            return nil
        }

        let parameters = contentType.split(separator: ";").dropFirst()
        for parameter in parameters {
            let keyValue = parameter.split(separator: "=", maxSplits: 1)
            guard keyValue.count == 2 else {
                continue
            }
            let key = keyValue[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard key == "version" else {
                continue
            }
            var value = keyValue[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value.removeFirst()
                value.removeLast()
            }
            if !value.isEmpty {
                return value
            }
        }

        return nil
    }
}

private struct JSONResultResponse: Decodable {
    struct Head: Decodable {
        let vars: [String]
    }

    struct Results: Decodable {
        let bindings: [[String: JSONBindingValue]]
    }

    let head: Head?
    let results: Results?
    let boolean: Bool?
    let version: String?
}

private final class JSONBindingValue: Decodable {
    let type: String
    let value: JSONValue
    let datatype: String?
    let language: String?
    let direction: String?

    enum CodingKeys: String, CodingKey {
        case type
        case value
        case datatype
        case language = "xml:lang"
        case direction = "its:dir"
    }

    var asTerm: ObjectTerm {
        get throws {
            switch type {
            case "uri":
                guard case let .string(value) = value else {
                    throw SPARQLError.decodingFailure("IRI term value must be a string.")
                }
                return try ObjectTerm(iri: value)
            case "bnode":
                guard case let .string(value) = value else {
                    throw SPARQLError.decodingFailure("Blank node value must be a string.")
                }
                return try ObjectTerm(blankNodeLabel: value)
            case "triple":
                guard case let .triple(tripleValue) = value else {
                    throw SPARQLError.decodingFailure("Triple term value must be an object.")
                }
                return try ObjectTerm(
                    subject: tripleValue.subject.asTerm,
                    predicate: tripleValue.predicate.asTerm,
                    object: tripleValue.object.asTerm
                )
            default:
                guard case let .string(value) = value else {
                    throw SPARQLError.decodingFailure("Literal term value must be a string.")
                }
                let baseDirection = direction.flatMap { BaseDirection(rawValue: $0.lowercased()) }
                return try ObjectTerm(literal: value, datatype: datatype, language: language, direction: baseDirection)
            }
        }
    }
}

private indirect enum JSONValue: Decodable {
    case string(String)
    case triple(JSONTripleValue)

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(), let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }

        let tripleValue = try JSONTripleValue(from: decoder)
        self = .triple(tripleValue)
    }
}

private final class JSONTripleValue: Decodable {
    let subject: JSONBindingValue
    let predicate: JSONBindingValue
    let object: JSONBindingValue
}
