import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import IRIKit
import RDFCore
import RDFFormats

/// The graph a Graph Store Protocol request acts on
/// (SPARQL 1.2 Graph Store HTTP Protocol §4).
public enum SPARQLGraphStoreGraph: Hashable, Sendable {
    /// The graph store itself, for a `POST` that creates a graph.
    case service
    /// The default graph, `?default`.
    case defaultGraph
    /// A named graph, `?graph=<iri>`.
    case named(IRI)
}

/// The conditional headers of a Graph Store Protocol request.
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

/// Where a Graph Store Protocol client sends requests.
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

/// A SPARQL 1.2 Graph Store HTTP Protocol client.
///
/// Graphs go out as N-Triples written by RDFFormats' ``NTriplesEncoder`` and
/// come back decoded by RDFFormats' decoders.
public struct SPARQLGraphStoreClient: Sendable {
    public let configuration: SPARQLGraphStoreConfiguration
    private let transport: SPARQLHTTPTransport

    public init(
        configuration: SPARQLGraphStoreConfiguration,
        session: any URLSessioning = URLSession.shared
    ) {
        self.configuration = configuration
        self.transport = SPARQLHTTPTransport(
            defaultHeaders: configuration.defaultHeaders,
            authentication: configuration.authentication,
            session: session
        )
    }

    /// `GET`: the graph's triples.
    public func getGraph(
        _ graph: SPARQLGraphStoreGraph = .defaultGraph,
        accept: SPARQLGraphAccept = .turtle,
        conditional: SPARQLConditionalRequest? = nil
    ) async throws -> Set<DecodedTriple> {
        let request = try makeRequest(method: "GET", graph: graph, accept: accept.rawValue, conditional: conditional)
        let (data, _) = try await transport.perform(request)
        return try SPARQLGraphResultDecoder().decode(data, as: accept)
    }

    /// `HEAD`: the response headers of a `GET`.
    public func headGraph(
        _ graph: SPARQLGraphStoreGraph = .defaultGraph,
        conditional: SPARQLConditionalRequest? = nil
    ) async throws -> HTTPURLResponse {
        try await transport.perform(try makeRequest(method: "HEAD", graph: graph, conditional: conditional)).1
    }

    /// `PUT`: replaces the graph with these triples.
    public func putGraph(
        _ triples: [DecodedTriple],
        graph: SPARQLGraphStoreGraph = .defaultGraph,
        conditional: SPARQLConditionalRequest? = nil
    ) async throws -> Data {
        try await send("PUT", triples, graph: graph, conditional: conditional)
    }

    /// `POST`: merges these triples into the graph, or creates a graph when
    /// sent to ``SPARQLGraphStoreGraph/service``.
    public func postGraph(
        _ triples: [DecodedTriple],
        graph: SPARQLGraphStoreGraph = .defaultGraph,
        conditional: SPARQLConditionalRequest? = nil
    ) async throws -> Data {
        try await send("POST", triples, graph: graph, conditional: conditional)
    }

    /// `DELETE`: removes the graph.
    public func deleteGraph(
        _ graph: SPARQLGraphStoreGraph = .defaultGraph,
        conditional: SPARQLConditionalRequest? = nil
    ) async throws -> Data {
        try await transport.perform(try makeRequest(method: "DELETE", graph: graph, conditional: conditional)).0
    }

    private func send(
        _ method: String,
        _ triples: [DecodedTriple],
        graph: SPARQLGraphStoreGraph,
        conditional: SPARQLConditionalRequest?
    ) async throws -> Data {
        let request = try makeRequest(
            method: method,
            graph: graph,
            contentType: SPARQLGraphAccept.ntriples.rawValue,
            body: Data(NTriplesEncoder().encode(triples).utf8),
            conditional: conditional
        )
        return try await transport.perform(request).0
    }

    func makeRequest(
        method: String,
        graph: SPARQLGraphStoreGraph,
        accept: String? = nil,
        contentType: String? = nil,
        body: Data? = nil,
        conditional: SPARQLConditionalRequest? = nil
    ) throws -> URLRequest {
        var components = URLComponents(url: configuration.graphStoreURL, resolvingAgainstBaseURL: false)
        switch graph {
        case .service:
            components?.queryItems = nil
        case .defaultGraph:
            components?.queryItems = [URLQueryItem(name: "default", value: nil)]
        case .named(let iri):
            components?.queryItems = [URLQueryItem(name: "graph", value: iri.rawValue)]
        }
        guard let url = components?.url else {
            throw SPARQLError.invalidRequest("The graph does not fit in a request URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        if let accept { request.setValue(accept, forHTTPHeaderField: "Accept") }
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        try transport.applyHeaders(to: &request)
        if let conditional {
            request.setValue(conditional.ifMatch, forHTTPHeaderField: "If-Match")
            request.setValue(conditional.ifNoneMatch, forHTTPHeaderField: "If-None-Match")
            request.setValue(conditional.ifUnmodifiedSince, forHTTPHeaderField: "If-Unmodified-Since")
            request.setValue(conditional.ifModifiedSince, forHTTPHeaderField: "If-Modified-Since")
        }
        return request
    }
}
