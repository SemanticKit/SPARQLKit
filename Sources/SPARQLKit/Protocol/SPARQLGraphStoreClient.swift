import Foundation

public enum SPARQLGraphReference: Hashable, Sendable {
    case service
    case defaultGraph
    case named(String)
}

public struct SPARQLConditionalRequest: Hashable, Sendable {
    public let ifMatch: String?
    public let ifNoneMatch: String?
    public let ifUnmodifiedSince: String?
    public let ifModifiedSince: String?

    public init(
        ifMatch: String? = nil,
        ifNoneMatch: String? = nil,
        ifUnmodifiedSince: String? = nil,
        ifModifiedSince: String? = nil
    ) {
        self.ifMatch = ifMatch
        self.ifNoneMatch = ifNoneMatch
        self.ifUnmodifiedSince = ifUnmodifiedSince
        self.ifModifiedSince = ifModifiedSince
    }
}

public struct SPARQLGraphStoreConfiguration: Sendable {
    public let graphStoreURL: URL
    public let defaultHeaders: [String: String]
    public let authentication: EndpointAuthentication?

    public init(
        graphStoreURL: URL,
        defaultHeaders: [String: String] = [:],
        authentication: EndpointAuthentication? = nil
    ) {
        self.graphStoreURL = graphStoreURL
        self.defaultHeaders = defaultHeaders
        self.authentication = authentication
    }
}

public struct SPARQLGraphStoreClient: Sendable {
    public let configuration: SPARQLGraphStoreConfiguration
    private let session: URLSessioning

    public init(
        configuration: SPARQLGraphStoreConfiguration,
        session: URLSessioning = URLSession.shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    public func getGraph(
        graph: SPARQLGraphReference = .defaultGraph,
        accept: SPARQLGraphAccept = .turtle,
        conditional: SPARQLConditionalRequest? = nil
    ) async throws -> Data {
        let request = try makeRequest(
            method: "GET",
            graph: graph,
            accept: accept.rawValue,
            conditional: conditional
        )
        return try await perform(request)
    }

    public func headGraph(
        graph: SPARQLGraphReference = .defaultGraph,
        conditional: SPARQLConditionalRequest? = nil
    ) async throws -> HTTPURLResponse {
        let request = try makeRequest(
            method: "HEAD",
            graph: graph,
            conditional: conditional
        )
        return try await performHead(request)
    }

    public func putGraph(
        _ data: Data,
        contentType: String,
        graph: SPARQLGraphReference = .defaultGraph,
        conditional: SPARQLConditionalRequest? = nil
    ) async throws -> Data {
        let request = try makeRequest(
            method: "PUT",
            graph: graph,
            contentType: contentType,
            body: data,
            conditional: conditional
        )
        return try await perform(request)
    }

    public func postGraph(
        _ data: Data,
        contentType: String,
        graph: SPARQLGraphReference = .defaultGraph,
        conditional: SPARQLConditionalRequest? = nil
    ) async throws -> Data {
        let request = try makeRequest(
            method: "POST",
            graph: graph,
            contentType: contentType,
            body: data,
            conditional: conditional
        )
        return try await perform(request)
    }

    public func deleteGraph(
        graph: SPARQLGraphReference = .defaultGraph,
        conditional: SPARQLConditionalRequest? = nil
    ) async throws -> Data {
        let request = try makeRequest(
            method: "DELETE",
            graph: graph,
            conditional: conditional
        )
        return try await perform(request)
    }

    func makeRequest(
        method: String,
        graph: SPARQLGraphReference,
        accept: String? = nil,
        contentType: String? = nil,
        body: Data? = nil,
        conditional: SPARQLConditionalRequest? = nil
    ) throws -> URLRequest {
        var request = URLRequest(url: try makeGraphURL(graph: graph))
        request.httpMethod = method
        request.httpBody = body
        if let accept {
            request.setValue(accept, forHTTPHeaderField: "Accept")
        }
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        try applyHeaders(to: &request)
        applyConditionalHeaders(conditional, to: &request)
        return request
    }

    private func makeGraphURL(graph: SPARQLGraphReference) throws -> URL {
        var components = URLComponents(url: configuration.graphStoreURL, resolvingAgainstBaseURL: false)
        switch graph {
        case .service:
            components?.queryItems = nil
        case .defaultGraph:
            components?.queryItems = [URLQueryItem(name: "default", value: nil)]
        case let .named(iri):
            components?.queryItems = [URLQueryItem(name: "graph", value: iri)]
        }

        guard let url = components?.url else {
            throw SPARQLError.invalidResponse
        }
        return url
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SPARQLError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw SPARQLError.httpStatus(http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    private func performHead(_ request: URLRequest) async throws -> HTTPURLResponse {
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SPARQLError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw SPARQLError.httpStatus(http.statusCode, body: "")
        }
        return http
    }

    private func applyHeaders(to request: inout URLRequest) throws {
        for (header, value) in configuration.defaultHeaders {
            try validateHeader(name: header, value: value)
            request.setValue(value, forHTTPHeaderField: header)
        }

        guard let authentication = configuration.authentication else {
            return
        }

        switch authentication.scheme {
        case let .bearer(token):
            let value = "Bearer \(token)"
            try validateHeader(name: "Authorization", value: value)
            request.setValue(value, forHTTPHeaderField: "Authorization")
        case let .basic(username, password):
            let credentials = "\(username):\(password)"
            let encoded = Data(credentials.utf8).base64EncodedString()
            let value = "Basic \(encoded)"
            try validateHeader(name: "Authorization", value: value)
            request.setValue(value, forHTTPHeaderField: "Authorization")
        }
    }

    private func applyConditionalHeaders(_ conditional: SPARQLConditionalRequest?, to request: inout URLRequest) {
        guard let conditional else {
            return
        }
        if let ifMatch = conditional.ifMatch {
            request.setValue(ifMatch, forHTTPHeaderField: "If-Match")
        }
        if let ifNoneMatch = conditional.ifNoneMatch {
            request.setValue(ifNoneMatch, forHTTPHeaderField: "If-None-Match")
        }
        if let ifUnmodifiedSince = conditional.ifUnmodifiedSince {
            request.setValue(ifUnmodifiedSince, forHTTPHeaderField: "If-Unmodified-Since")
        }
        if let ifModifiedSince = conditional.ifModifiedSince {
            request.setValue(ifModifiedSince, forHTTPHeaderField: "If-Modified-Since")
        }
    }

    private func validateHeader(name: String, value: String) throws {
        if containsInvalidHeaderCharacters(name) || containsInvalidHeaderCharacters(value) {
            throw SPARQLError.invalidRequest("HTTP header names/values must not contain control characters.")
        }
    }

    private func containsInvalidHeaderCharacters(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            scalar == "\r" || scalar == "\n" || (scalar.value < 0x20 && scalar != "\t")
        }
    }
}
