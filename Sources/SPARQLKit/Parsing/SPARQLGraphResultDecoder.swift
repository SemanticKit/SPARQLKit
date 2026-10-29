import Foundation
import IRIKit
import RDFCore
import RDFFormats

/// Decodes the graph a `CONSTRUCT` or `DESCRIBE` query returns, or a graph
/// the Graph Store Protocol sends, with RDFFormats' decoders.
///
/// RDF 1.2 Concepts §3.4: an RDF graph is a set of RDF triples, so the result
/// is a `Set`.
public struct SPARQLGraphResultDecoder: Sendable {
    public init() {}

    /// Decodes a graph in the given media type.
    ///
    /// - Parameter base: The IRI relative references in a Turtle document
    ///   resolve against, usually the request IRI.
    public func decode(_ data: Data, as format: SPARQLGraphAccept, base: IRI? = nil) throws -> Set<DecodedTriple> {
        guard let document = String(data: data, encoding: .utf8) else {
            throw SPARQLError.decodingFailure("Graph result payload is not UTF-8.")
        }
        do {
            switch format {
            case .turtle:
                return Set(try TurtleDecoder(base: base).decode(document))
            case .ntriples:
                return Set(try NTriplesDecoder().decode(document))
            case .rdfXML, .jsonLD:
                throw SPARQLError.decodingFailure("RDFFormats has no \(format.rawValue) decoder.")
            }
        } catch let error as SPARQLError {
            throw error
        } catch {
            throw SPARQLError.decodingFailure("Failed to decode \(format.rawValue) graph result: \(error)")
        }
    }
}
