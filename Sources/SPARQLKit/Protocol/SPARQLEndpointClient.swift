import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct SPARQLQueryRequestOptions: Sendable, Hashable {
    public let defaultGraphURIs: [String]
    public let namedGraphURIs: [String]
    public let requiredEntailmentRegime: String?

    public init(
        defaultGraphURIs: [String] = [],
        namedGraphURIs: [String] = [],
        requiredEntailmentRegime: String? = nil
    ) {
        self.defaultGraphURIs = defaultGraphURIs
        self.namedGraphURIs = namedGraphURIs
        self.requiredEntailmentRegime = requiredEntailmentRegime
    }

    public init(dataset: SPARQLDataset, requiredEntailmentRegime: String? = nil) {
        self.init(
            defaultGraphURIs: dataset.defaultGraphURIs,
            namedGraphURIs: dataset.namedGraphURIs,
            requiredEntailmentRegime: requiredEntailmentRegime
        )
    }
}

public struct SPARQLUpdateRequestOptions: Sendable, Hashable {
    public let usingGraphURIs: [String]
    public let usingNamedGraphURIs: [String]

    public init(usingGraphURIs: [String] = [], usingNamedGraphURIs: [String] = []) {
        self.usingGraphURIs = usingGraphURIs
        self.usingNamedGraphURIs = usingNamedGraphURIs
    }

    public init(dataset: SPARQLDataset) {
        self.init(
            usingGraphURIs: dataset.usingGraphURIs,
            usingNamedGraphURIs: dataset.usingNamedGraphURIs
        )
    }
}

public enum SPARQLUpdateBatchExecutionMode: Sendable, Hashable {
    case singleRequestAtomic
    case sequentialRequests
}

public struct EndpointAuthentication: Sendable {
    public enum Scheme: Sendable {
        case bearer(token: String)
        case basic(username: String, password: String)
    }

    public let scheme: Scheme

    public init(scheme: Scheme) {
        self.scheme = scheme
    }
}

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

public protocol URLSessioning: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

#if canImport(FoundationNetworking)
extension URLSession: URLSessioning {
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
}
#else
extension URLSession: URLSessioning {}
#endif

public enum SPARQLHTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

public struct SPARQLEndpointClient: Sendable {
    public let configuration: SPARQLEndpointConfiguration
    private let session: URLSessioning

    public init(
        configuration: SPARQLEndpointConfiguration,
        session: URLSessioning = URLSession.shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    public func executeQuery(
        _ query: some SPARQLQueryRenderable,
        accept: SPARQLAccept = .jsonResults,
        method: SPARQLHTTPMethod = .post,
        options: SPARQLQueryRequestOptions = .init(),
        serviceDescription: SPARQLServiceDescription? = nil
    ) async throws -> Data {
        if query is SPARQLConstructQuery || query is SPARQLDescribeQuery {
            throw SPARQLError.invalidRequest(
                "CONSTRUCT/DESCRIBE queries require graph media type accept headers."
            )
        }
        if let serviceDescription, !serviceDescription.supports(accept) {
            throw SPARQLError.invalidRequest("Endpoint service description does not support requested result format.")
        }
        if let requiredEntailmentRegime = options.requiredEntailmentRegime,
           let serviceDescription,
           !serviceDescription.supportsEntailment(requiredEntailmentRegime)
        {
            throw SPARQLError.invalidRequest("Endpoint service description does not support requested entailment regime.")
        }
        let request = try makeQueryRequest(query.render(), accept: accept, method: method, options: options)
        return try await perform(request)
    }

    public func executeQuery(
        _ query: some SPARQLQueryRenderable,
        accept: SPARQLAccept = .jsonResults,
        method: SPARQLHTTPMethod = .post,
        dataset: SPARQLDataset,
        requiredEntailmentRegime: String? = nil,
        serviceDescription: SPARQLServiceDescription? = nil
    ) async throws -> Data {
        try await executeQuery(
            query,
            accept: accept,
            method: method,
            options: SPARQLQueryRequestOptions(
                dataset: dataset,
                requiredEntailmentRegime: requiredEntailmentRegime
            ),
            serviceDescription: serviceDescription
        )
    }

    public func executeSelect(
        _ query: SPARQLSelectQuery,
        method: SPARQLHTTPMethod = .post,
        options: SPARQLQueryRequestOptions = .init(),
        serviceDescription: SPARQLServiceDescription? = nil
    ) async throws -> SPARQLResultSet {
        let data = try await executeQuery(
            query,
            accept: .jsonResults,
            method: method,
            options: options,
            serviceDescription: serviceDescription
        )
        return try SPARQLJSONResultDecoder().decode(data)
    }

    public func executeSelect(
        _ query: SPARQLSelectQuery,
        method: SPARQLHTTPMethod = .post,
        dataset: SPARQLDataset,
        requiredEntailmentRegime: String? = nil,
        serviceDescription: SPARQLServiceDescription? = nil
    ) async throws -> SPARQLResultSet {
        try await executeSelect(
            query,
            method: method,
            options: SPARQLQueryRequestOptions(
                dataset: dataset,
                requiredEntailmentRegime: requiredEntailmentRegime
            ),
            serviceDescription: serviceDescription
        )
    }

    public func executeAsk(
        _ query: SPARQLAskQuery,
        method: SPARQLHTTPMethod = .post,
        options: SPARQLQueryRequestOptions = .init(),
        serviceDescription: SPARQLServiceDescription? = nil
    ) async throws -> Bool {
        let data = try await executeQuery(
            query,
            accept: .jsonResults,
            method: method,
            options: options,
            serviceDescription: serviceDescription
        )
        let result = try SPARQLJSONResultDecoder().decodeQueryResult(data)
        guard case let .boolean(value) = result else {
            throw SPARQLError.decodingFailure("Expected ASK boolean result payload.")
        }
        return value
    }

    public func executeAsk(
        _ query: SPARQLAskQuery,
        method: SPARQLHTTPMethod = .post,
        dataset: SPARQLDataset,
        requiredEntailmentRegime: String? = nil,
        serviceDescription: SPARQLServiceDescription? = nil
    ) async throws -> Bool {
        try await executeAsk(
            query,
            method: method,
            options: SPARQLQueryRequestOptions(
                dataset: dataset,
                requiredEntailmentRegime: requiredEntailmentRegime
            ),
            serviceDescription: serviceDescription
        )
    }

    public func executeFederatedSelect(
        _ query: SPARQLFederatedSelectQuery,
        method: SPARQLHTTPMethod = .post,
        options: SPARQLQueryRequestOptions = .init(),
        serviceDescription: SPARQLServiceDescription? = nil
    ) async throws -> SPARQLResultSet {
        let data = try await executeQuery(
            query,
            accept: .jsonResults,
            method: method,
            options: options,
            serviceDescription: serviceDescription
        )
        return try SPARQLJSONResultDecoder().decode(data)
    }

    public func executeFederatedSelect(
        _ query: SPARQLFederatedSelectQuery,
        method: SPARQLHTTPMethod = .post,
        dataset: SPARQLDataset,
        requiredEntailmentRegime: String? = nil,
        serviceDescription: SPARQLServiceDescription? = nil
    ) async throws -> SPARQLResultSet {
        try await executeFederatedSelect(
            query,
            method: method,
            options: SPARQLQueryRequestOptions(
                dataset: dataset,
                requiredEntailmentRegime: requiredEntailmentRegime
            ),
            serviceDescription: serviceDescription
        )
    }

    public func executeGraphQuery(
        _ query: some SPARQLQueryRenderable,
        accept: SPARQLGraphAccept = .turtle,
        method: SPARQLHTTPMethod = .post,
        options: SPARQLQueryRequestOptions = .init(),
        serviceDescription: SPARQLServiceDescription? = nil
    ) async throws -> Data {
        guard query is SPARQLConstructQuery || query is SPARQLDescribeQuery else {
            throw SPARQLError.invalidRequest(
                "Graph query execution is only valid for CONSTRUCT or DESCRIBE."
            )
        }
        if let serviceDescription, !serviceDescription.supports(accept) {
            throw SPARQLError.invalidRequest("Endpoint service description does not support requested graph format.")
        }
        if let requiredEntailmentRegime = options.requiredEntailmentRegime,
           let serviceDescription,
           !serviceDescription.supportsEntailment(requiredEntailmentRegime)
        {
            throw SPARQLError.invalidRequest("Endpoint service description does not support requested entailment regime.")
        }
        let request = try makeQueryRequest(query.render(), accept: accept.rawValue, method: method, options: options)
        return try await perform(request)
    }

    public func executeGraphQuery(
        _ query: some SPARQLQueryRenderable,
        accept: SPARQLGraphAccept = .turtle,
        method: SPARQLHTTPMethod = .post,
        dataset: SPARQLDataset,
        requiredEntailmentRegime: String? = nil,
        serviceDescription: SPARQLServiceDescription? = nil
    ) async throws -> Data {
        try await executeGraphQuery(
            query,
            accept: accept,
            method: method,
            options: SPARQLQueryRequestOptions(
                dataset: dataset,
                requiredEntailmentRegime: requiredEntailmentRegime
            ),
            serviceDescription: serviceDescription
        )
    }

    public func executeConstruct(
        _ query: SPARQLConstructQuery,
        accept: SPARQLGraphAccept = .turtle,
        method: SPARQLHTTPMethod = .post,
        options: SPARQLQueryRequestOptions = .init(),
        serviceDescription: SPARQLServiceDescription? = nil
    ) async throws -> Data {
        try await executeGraphQuery(
            query,
            accept: accept,
            method: method,
            options: options,
            serviceDescription: serviceDescription
        )
    }

    public func executeConstruct(
        _ query: SPARQLConstructQuery,
        accept: SPARQLGraphAccept = .turtle,
        method: SPARQLHTTPMethod = .post,
        dataset: SPARQLDataset,
        requiredEntailmentRegime: String? = nil,
        serviceDescription: SPARQLServiceDescription? = nil
    ) async throws -> Data {
        try await executeConstruct(
            query,
            accept: accept,
            method: method,
            options: SPARQLQueryRequestOptions(
                dataset: dataset,
                requiredEntailmentRegime: requiredEntailmentRegime
            ),
            serviceDescription: serviceDescription
        )
    }

    public func executeDescribe(
        _ query: SPARQLDescribeQuery,
        accept: SPARQLGraphAccept = .turtle,
        method: SPARQLHTTPMethod = .post,
        options: SPARQLQueryRequestOptions = .init(),
        serviceDescription: SPARQLServiceDescription? = nil
    ) async throws -> Data {
        try await executeGraphQuery(
            query,
            accept: accept,
            method: method,
            options: options,
            serviceDescription: serviceDescription
        )
    }

    public func executeDescribe(
        _ query: SPARQLDescribeQuery,
        accept: SPARQLGraphAccept = .turtle,
        method: SPARQLHTTPMethod = .post,
        dataset: SPARQLDataset,
        requiredEntailmentRegime: String? = nil,
        serviceDescription: SPARQLServiceDescription? = nil
    ) async throws -> Data {
        try await executeDescribe(
            query,
            accept: accept,
            method: method,
            options: SPARQLQueryRequestOptions(
                dataset: dataset,
                requiredEntailmentRegime: requiredEntailmentRegime
            ),
            serviceDescription: serviceDescription
        )
    }

    public func executeUpdate(
        _ update: String,
        options: SPARQLUpdateRequestOptions = .init()
    ) async throws -> Data {
        let request = try makeUpdateRequest(update, options: options)
        return try await perform(request)
    }

    public func executeUpdate(
        _ update: String,
        dataset: SPARQLDataset
    ) async throws -> Data {
        try await executeUpdate(
            update,
            options: SPARQLUpdateRequestOptions(dataset: dataset)
        )
    }

    public func executeUpdate(
        _ updateRequest: SPARQLUpdateRequest,
        options: SPARQLUpdateRequestOptions = .init()
    ) async throws -> Data {
        try await executeUpdate(updateRequest.render(), options: options)
    }

    public func executeUpdate(
        _ updateRequest: SPARQLUpdateRequest,
        dataset: SPARQLDataset
    ) async throws -> Data {
        try await executeUpdate(
            updateRequest,
            options: SPARQLUpdateRequestOptions(dataset: dataset)
        )
    }

    public func executeUpdateBatch(
        _ updateRequest: SPARQLUpdateRequest,
        mode: SPARQLUpdateBatchExecutionMode = .singleRequestAtomic,
        options: SPARQLUpdateRequestOptions = .init()
    ) async throws -> [Data] {
        guard !updateRequest.operations.isEmpty else {
            throw SPARQLError.invalidRequest("SPARQL update request must contain at least one operation.")
        }

        switch mode {
        case .singleRequestAtomic:
            return [try await executeUpdate(updateRequest, options: options)]
        case .sequentialRequests:
            var responses: [Data] = []
            responses.reserveCapacity(updateRequest.operations.count)

            for operation in updateRequest.operations {
                let request = SPARQLUpdateRequest(operations: [operation])
                let data = try await executeUpdate(request, options: options)
                responses.append(data)
            }

            return responses
        }
    }

    public func executeInsertData(
        triples: [String],
        options: SPARQLUpdateRequestOptions = .init()
    ) async throws -> Data {
        let update = SPARQLUpdateRequest(operations: [.insertData(triples: triples)])
        return try await executeUpdate(update, options: options)
    }

    public func executeDeleteData(
        triples: [String],
        options: SPARQLUpdateRequestOptions = .init()
    ) async throws -> Data {
        let update = SPARQLUpdateRequest(operations: [.deleteData(triples: triples)])
        return try await executeUpdate(update, options: options)
    }

    public func executeDeleteInsertWhere(
        delete: [String],
        insert: [String],
        wherePatterns: [String],
        options: SPARQLUpdateRequestOptions = .init()
    ) async throws -> Data {
        let update = SPARQLUpdateRequest(
            operations: [
                .deleteInsertWhere(
                    delete: delete,
                    insert: insert,
                    wherePatterns: wherePatterns
                )
            ]
        )
        return try await executeUpdate(update, options: options)
    }

    public func executeLoad(
        source: String,
        intoGraph: String? = nil,
        options: SPARQLUpdateRequestOptions = .init()
    ) async throws -> Data {
        let update = SPARQLUpdateRequest(operations: [.load(source: source, intoGraph: intoGraph)])
        return try await executeUpdate(update, options: options)
    }

    public func executeClear(
        target: SPARQLGraphTarget,
        silent: Bool = false,
        options: SPARQLUpdateRequestOptions = .init()
    ) async throws -> Data {
        let update = SPARQLUpdateRequest(operations: [.clear(target: target, silent: silent)])
        return try await executeUpdate(update, options: options)
    }

    public func executeCreate(
        graph: String,
        silent: Bool = false,
        options: SPARQLUpdateRequestOptions = .init()
    ) async throws -> Data {
        let update = SPARQLUpdateRequest(operations: [.create(graph: graph, silent: silent)])
        return try await executeUpdate(update, options: options)
    }

    public func executeDrop(
        target: SPARQLGraphTarget,
        silent: Bool = false,
        options: SPARQLUpdateRequestOptions = .init()
    ) async throws -> Data {
        let update = SPARQLUpdateRequest(operations: [.drop(target: target, silent: silent)])
        return try await executeUpdate(update, options: options)
    }

    public func executeCopy(
        from: String,
        to: String,
        silent: Bool = false,
        options: SPARQLUpdateRequestOptions = .init()
    ) async throws -> Data {
        let update = SPARQLUpdateRequest(operations: [.copy(from: from, to: to, silent: silent)])
        return try await executeUpdate(update, options: options)
    }

    public func executeMove(
        from: String,
        to: String,
        silent: Bool = false,
        options: SPARQLUpdateRequestOptions = .init()
    ) async throws -> Data {
        let update = SPARQLUpdateRequest(operations: [.move(from: from, to: to, silent: silent)])
        return try await executeUpdate(update, options: options)
    }

    public func executeAdd(
        from: String,
        to: String,
        silent: Bool = false,
        options: SPARQLUpdateRequestOptions = .init()
    ) async throws -> Data {
        let update = SPARQLUpdateRequest(operations: [.add(from: from, to: to, silent: silent)])
        return try await executeUpdate(update, options: options)
    }

    func makeQueryRequest(
        _ query: String,
        accept: SPARQLAccept,
        method: SPARQLHTTPMethod,
        options: SPARQLQueryRequestOptions = .init()
    ) throws -> URLRequest {
        try makeQueryRequest(query, accept: accept.rawValue, method: method, options: options)
    }

    func makeQueryRequest(
        _ query: String,
        accept: String,
        method: SPARQLHTTPMethod,
        options: SPARQLQueryRequestOptions = .init()
    ) throws -> URLRequest {
        let datasetItems: [URLQueryItem] =
            options.defaultGraphURIs.map { URLQueryItem(name: "default-graph-uri", value: $0) }
            + options.namedGraphURIs.map { URLQueryItem(name: "named-graph-uri", value: $0) }

        switch method {
        case .get:
            var components = URLComponents(url: configuration.queryURL, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "query", value: query)] + datasetItems
            guard let url = components?.url else {
                throw SPARQLError.invalidResponse
            }

            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue
            request.timeoutInterval = configuration.requestTimeout
            request.setValue(accept, forHTTPHeaderField: "Accept")
            try applyHeaders(to: &request)
            return request

        case .post:
            var request = URLRequest(url: configuration.queryURL)
            request.httpMethod = method.rawValue
            request.timeoutInterval = configuration.requestTimeout
            request.httpBody = formURLEncoded(
                [("query", query)]
                    + options.defaultGraphURIs.map { ("default-graph-uri", $0) }
                    + options.namedGraphURIs.map { ("named-graph-uri", $0) }
            )
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue(accept, forHTTPHeaderField: "Accept")
            try applyHeaders(to: &request)
            return request
        }
    }

    func makeUpdateRequest(
        _ update: String,
        options: SPARQLUpdateRequestOptions = .init()
    ) throws -> URLRequest {
        let updateURL = configuration.updateURL ?? configuration.queryURL

        var request = URLRequest(url: updateURL)
        request.httpMethod = SPARQLHTTPMethod.post.rawValue
        request.timeoutInterval = configuration.requestTimeout
        request.httpBody = formURLEncoded(
            [("update", update)]
                + options.usingGraphURIs.map { ("using-graph-uri", $0) }
                + options.usingNamedGraphURIs.map { ("using-named-graph-uri", $0) }
        )
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        try applyHeaders(to: &request)
        return request
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

    private func applyHeaders(to request: inout URLRequest) throws {
        for (header, value) in configuration.defaultHeaders {
            try validateHeader(name: header, value: value)
            request.setValue(value, forHTTPHeaderField: header)
        }

        guard let authentication else {
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

    private var authentication: EndpointAuthentication? {
        configuration.authentication
    }

    private func formURLEncoded(_ pairs: [(String, String)]) -> Data {
        let encoded = pairs
            .map { "\($0.0)=\(percentEncodeFormValue($0.1))" }
            .joined(separator: "&")
        return Data(encoded.utf8)
    }

    private func percentEncodeFormValue(_ string: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
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
