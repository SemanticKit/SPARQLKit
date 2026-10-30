import Foundation
import RDFCore
import RDFFormats

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

/// Decodes SPARQL 1.2 Query Results JSON documents.
///
/// Each term in the document is read by an ``RDFCore/ObjectTerm``
/// initializer as the document is decoded (SPARQL 1.2 Query Results JSON
/// Format §3.2.2).
public struct SPARQLJSONResultDecoder: Sendable {
    public init() {}

    /// Decodes a results document, with the version it announces in its
    /// `version` member or, failing that, in the `version` parameter of its
    /// media type.
    public func decode(_ data: Data, contentType: String?) throws -> SPARQLDecodedQueryResult {
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

            let variables = try (head.vars ?? []).map(Variable.init(resultName:))
            let bindings = try results.bindings.map { row in
                try row.reduce(into: Binding()) { partial, entry in
                    partial[try Variable(resultName: entry.key)] = try ObjectTerm(entry.value)
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

    /// Decodes a results document: the solutions of a `SELECT` query or the
    /// answer to an `ASK` query.
    public func decode(_ data: Data) throws -> SPARQLQueryResult {
        try (decode(data, contentType: nil) as SPARQLDecodedQueryResult).result
    }

    /// Decodes the solutions of a `SELECT` query.
    ///
    /// - Throws: ``SPARQLError/decodingFailure(_:)`` when the document is
    ///   the answer to an `ASK` query.
    public func decode(_ data: Data) throws -> SPARQLResultSet {
        switch try decode(data) as SPARQLQueryResult {
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
    /// The head of a results document. An `ASK` result's head has no
    /// `vars` (SPARQL 1.2 Query Results JSON Format §3.1).
    struct Head: Decodable {
        let vars: [String]?
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
}

extension ObjectTerm {
    /// A term in a JSON results document: an object whose `type` says which
    /// kind of term it is (SPARQL 1.2 Query Results JSON Format §3.2.2).
    fileprivate init(_ value: JSONBindingValue) throws {
        switch (value.type, value.value) {
        case ("uri", .string(let text)):
            try self.init(iri: text)
        case ("bnode", .string(let label)):
            try self.init(blankNode: label)
        case ("triple", .triple(let triple)):
            try self.init(
                tripleTermSubject: try ObjectTerm(triple.subject),
                predicate: try ObjectTerm(triple.predicate),
                object: try ObjectTerm(triple.object)
            )
        case ("literal", .string(let lexicalForm)):
            try self.init(
                literal: lexicalForm,
                datatype: value.datatype,
                language: value.language,
                direction: value.direction
            )
        case ("triple", _):
            throw SPARQLError.decodingFailure("A triple term value must be an object.")
        case ("uri", _), ("bnode", _), ("literal", _):
            throw SPARQLError.decodingFailure("A \(value.type) value must be a string.")
        default:
            throw SPARQLError.decodingFailure("'\(value.type)' is not a term type.")
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
