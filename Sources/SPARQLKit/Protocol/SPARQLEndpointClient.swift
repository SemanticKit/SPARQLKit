import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import IRIKit
import RDFCore
import RDFFormats
import ServiceDescription

/// The dataset and entailment regime a query request asks for
/// (SPARQL 1.2 Protocol §2.1.4).
public struct SPARQLQueryRequestOptions: Sendable {
    /// The `default-graph-uri` parameters.
    public let defaultGraphs: [IRI]
    /// The `named-graph-uri` parameters.
    public let namedGraphs: [IRI]
    /// An entailment regime the endpoint's service description must name.
    public let requiredEntailmentRegime: (any ServiceDescription.EntailmentRegime)?

    public init(
        defaultGraphs: [IRI] = [],
        namedGraphs: [IRI] = [],
        requiredEntailmentRegime: (any ServiceDescription.EntailmentRegime)? = nil
    ) {
        self.defaultGraphs = defaultGraphs
        self.namedGraphs = namedGraphs
        self.requiredEntailmentRegime = requiredEntailmentRegime
    }
}

/// The dataset an update request names (SPARQL 1.2 Protocol §2.2.3).
public struct SPARQLUpdateRequestOptions: Sendable, Hashable {
    /// The `using-graph-uri` parameters.
    public let usingGraphs: [IRI]
    /// The `using-named-graph-uri` parameters.
    public let usingNamedGraphs: [IRI]

    public init(usingGraphs: [IRI] = [], usingNamedGraphs: [IRI] = []) {
        self.usingGraphs = usingGraphs
        self.usingNamedGraphs = usingNamedGraphs
    }
}

/// How ``SPARQLEndpointClient/executeUpdateBatch(_:mode:options:)`` sends
/// the operations of a request.
public enum SPARQLUpdateBatchExecutionMode: Sendable, Hashable {
    /// One request holding every operation.
    case singleRequestAtomic
    /// One request per operation, in order.
    case sequentialRequests
}

/// Where a client sends queries and updates.
public struct SPARQLEndpointConfiguration: Sendable {
    public let queryURL: URL
    public let updateURL: URL?
    public let defaultHeaders: [String: String]
    public let authentication: EndpointAuthentication?
    public let requestTimeout: TimeInterval

    public init(
        queryURL: URL,
        updateURL: URL? = nil,
        defaultHeaders: [String: String] = [:],
        authentication: EndpointAuthentication? = nil,
        requestTimeout: TimeInterval = 60
    ) {
        self.queryURL = queryURL
        self.updateURL = updateURL
        self.defaultHeaders = defaultHeaders
        self.authentication = authentication
        self.requestTimeout = requestTimeout
    }
}

/// The HTTP method of a query request (SPARQL 1.2 Protocol §2.1).
public enum SPARQLHTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

/// A SPARQL Protocol client (SPARQL 1.2 Protocol §2).
///
/// The client takes typed queries and updates, renders them to SPARQL text as
/// it builds each request, and decodes what the endpoint returns.
public struct SPARQLEndpointClient: Sendable {
    public let configuration: SPARQLEndpointConfiguration
    private let transport: SPARQLHTTPTransport

    public init(
        configuration: SPARQLEndpointConfiguration,
        session: any URLSessioning = URLSession.shared
    ) {
        self.configuration = configuration
        self.transport = SPARQLHTTPTransport(
            defaultHeaders: configuration.defaultHeaders,
            authentication: configuration.authentication,
            session: session
        )
    }

    /// Sends a `SELECT` or `ASK` query and returns the results document.
    public func executeQuery(
        _ query: some SPARQLResultsQuery,
        accept: SPARQLAccept = .jsonResults,
        method: SPARQLHTTPMethod = .post,
        options: SPARQLQueryRequestOptions = .init(),
        serviceDescription: (any ServiceDescription.Service)? = nil
    ) async throws -> Data {
        if let serviceDescription, !serviceDescription.supports(accept) {
            throw SPARQLError.invalidRequest("Endpoint service description does not support requested result format.")
        }
        try check(options, against: serviceDescription)
        let request = try makeQueryRequest(query.render(), accept: accept.rawValue, method: method, options: options)
        return try await transport.perform(request).0
    }

    /// Sends a `SELECT` query and decodes its JSON results.
    public func executeSelect(
        _ query: SPARQLSelectQuery,
        method: SPARQLHTTPMethod = .post,
        options: SPARQLQueryRequestOptions = .init(),
        serviceDescription: (any ServiceDescription.Service)? = nil
    ) async throws -> SPARQLResultSet {
        let data = try await executeQuery(
            query, accept: .jsonResults, method: method, options: options, serviceDescription: serviceDescription
        )
        return try SPARQLJSONResultDecoder().decode(data)
    }

    /// Sends an `ASK` query and decodes its JSON boolean.
    public func executeAsk(
        _ query: SPARQLAskQuery,
        method: SPARQLHTTPMethod = .post,
        options: SPARQLQueryRequestOptions = .init(),
        serviceDescription: (any ServiceDescription.Service)? = nil
    ) async throws -> Bool {
        let data = try await executeQuery(
            query, accept: .jsonResults, method: method, options: options, serviceDescription: serviceDescription
        )
        guard case .boolean(let value) = try SPARQLJSONResultDecoder().decode(data) as SPARQLQueryResult else {
            throw SPARQLError.decodingFailure("Expected ASK boolean result payload.")
        }
        return value
    }

    /// Sends a `CONSTRUCT` or `DESCRIBE` query and decodes the graph it
    /// returns with RDFFormats.
    public func executeGraphQuery(
        _ query: some SPARQLGraphQuery,
        accept: SPARQLGraphAccept = .turtle,
        method: SPARQLHTTPMethod = .post,
        options: SPARQLQueryRequestOptions = .init(),
        serviceDescription: (any ServiceDescription.Service)? = nil
    ) async throws -> RDFCore.Graph {
        if let serviceDescription, !serviceDescription.supports(accept) {
            throw SPARQLError.invalidRequest("Endpoint service description does not support requested graph format.")
        }
        try check(options, against: serviceDescription)
        let request = try makeQueryRequest(query.render(), accept: accept.rawValue, method: method, options: options)
        let (data, response) = try await transport.perform(request)
        return try SPARQLGraphResultDecoder().decode(data, as: accept, base: transport.retrievalIRI(of: response, for: request))
    }

    /// Sends an update request.
    public func executeUpdate(
        _ update: SPARQLUpdateRequest,
        options: SPARQLUpdateRequestOptions = .init()
    ) async throws -> Data {
        guard !update.operations.isEmpty else {
            throw SPARQLError.invalidRequest("SPARQL update request must contain at least one operation.")
        }
        return try await transport.perform(try makeUpdateRequest(update.render(), options: options)).0
    }

    /// Sends the operations of an update request together or one at a time.
    public func executeUpdateBatch(
        _ update: SPARQLUpdateRequest,
        mode: SPARQLUpdateBatchExecutionMode = .singleRequestAtomic,
        options: SPARQLUpdateRequestOptions = .init()
    ) async throws -> [Data] {
        guard !update.operations.isEmpty else {
            throw SPARQLError.invalidRequest("SPARQL update request must contain at least one operation.")
        }
        switch mode {
        case .singleRequestAtomic:
            return [try await executeUpdate(update, options: options)]
        case .sequentialRequests:
            var responses: [Data] = []
            for operation in update.operations {
                responses.append(try await executeUpdate(try SPARQLUpdateRequest([operation]), options: options))
            }
            return responses
        }
    }

    private func check(_ options: SPARQLQueryRequestOptions, against description: (any ServiceDescription.Service)?) throws {
        if let regime = options.requiredEntailmentRegime, let description, !description.supportsEntailment(regime) {
            throw SPARQLError.invalidRequest("Endpoint service description does not support requested entailment regime.")
        }
    }

    /// The request that carries rendered query text (SPARQL 1.2 Protocol
    /// §2.1.2 and §2.1.3).
    func makeQueryRequest(
        _ query: String,
        accept: String,
        method: SPARQLHTTPMethod,
        options: SPARQLQueryRequestOptions = .init()
    ) throws -> URLRequest {
        let parameters: [(name: String, value: String?)] = [("query", query)]
            + options.defaultGraphs.map { ("default-graph-uri", $0.rawValue) }
            + options.namedGraphs.map { ("named-graph-uri", $0.rawValue) }
        var request: URLRequest
        switch method {
        case .get:
            var components = URLComponents(url: configuration.queryURL, resolvingAgainstBaseURL: false)
            components?.percentEncodedQuery = FormURLEncoder().encode(parameters)
            guard let url = components?.url else {
                throw SPARQLError.invalidRequest("The query does not fit in a request URL.")
            }
            request = URLRequest(url: url)
        case .post:
            request = URLRequest(url: configuration.queryURL)
            request.httpBody = Data(FormURLEncoder().encode(parameters).utf8)
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        request.httpMethod = method.rawValue
        request.timeoutInterval = configuration.requestTimeout
        request.setValue(accept, forHTTPHeaderField: "Accept")
        try transport.applyHeaders(to: &request)
        return request
    }

    /// The request that carries rendered update text (SPARQL 1.2 Protocol
    /// §2.2.1).
    func makeUpdateRequest(
        _ update: String,
        options: SPARQLUpdateRequestOptions = .init()
    ) throws -> URLRequest {
        var request = URLRequest(url: configuration.updateURL ?? configuration.queryURL)
        request.httpMethod = SPARQLHTTPMethod.post.rawValue
        request.timeoutInterval = configuration.requestTimeout
        let parameters: [(name: String, value: String?)] = [("update", update)]
            + options.usingGraphs.map { ("using-graph-uri", $0.rawValue) }
            + options.usingNamedGraphs.map { ("using-named-graph-uri", $0.rawValue) }
        request.httpBody = Data(FormURLEncoder().encode(parameters).utf8)
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        try transport.applyHeaders(to: &request)
        return request
    }
}
