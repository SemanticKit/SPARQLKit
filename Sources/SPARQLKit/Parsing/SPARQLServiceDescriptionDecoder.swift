import EntailmentRegimes
import Formats
import Foundation
import IRIKit
import RDF
import RDFCore
import RDFFormats
import ServiceDescription

/// Decodes a Turtle service description into the translated `sd:Service`
/// it describes (SPARQL 1.2 Service Description §3).
///
/// The document is read by RDFFormats' ``TurtleDecoder``. The service is an
/// instance of the generated `ServiceDescription.ServiceIndividual`, and each
/// IRI that names a language, feature, format or entailment regime becomes
/// the translated individual it denotes as it is read, so the decoded
/// service's `supportedLanguage`, `feature`, `resultFormat` and
/// `defaultEntailmentRegime` hold those individuals themselves. An IRI the
/// vocabularies do not declare, or one that denotes an individual outside
/// the property's range, names nothing SPARQLKit can act on, so it is left
/// out.
public struct SPARQLServiceDescriptionDecoder: Sendable {
    /// The individuals the vocabularies declare: the languages and features
    /// of sparql-service-description.ttl, the formats and the entailment
    /// regimes.
    static let vocabulary: [any RDFCore.Description] =
        ServiceDescription.ontology + Formats.ontology + EntailmentRegimes.ontology

    /// The properties whose domain is `sd:Service`: a node the document gives
    /// one of them is a service (RDF 1.2 Semantics, rdfs2).
    static let serviceProperties: [any RDFCore.Resource] = [
        ServiceDescription.endpoint, ServiceDescription.feature, ServiceDescription.defaultEntailmentRegime,
        ServiceDescription.defaultSupportedEntailmentProfile, ServiceDescription.extensionFunction,
        ServiceDescription.extensionAggregate, ServiceDescription.languageExtension,
        ServiceDescription.supportedLanguage, ServiceDescription.supportedVersion,
        ServiceDescription.propertyFeature, ServiceDescription.defaultDataset,
        ServiceDescription.availableGraphs, ServiceDescription.resultFormat, ServiceDescription.inputFormat
    ]

    public init() {}

    /// The service the document describes.
    ///
    /// - Throws: ``SPARQLError/decodingFailure(_:)`` when the document is not
    ///   Turtle, or describes no service or more than one.
    public func decode(_ turtle: String, base: IRI? = nil) throws -> any ServiceDescription.Service {
        let graph = try TurtleDecoder(base: base).decode(turtle)
        let services = graph.members(of: ServiceDescription.ServiceIndividual.self)
            .union(Self.serviceProperties.flatMap(graph.subjects))
        guard let node = services.first, services.count == 1 else {
            throw SPARQLError.decodingFailure(
                services.isEmpty ? "The document describes no sd:Service." : "The document describes \(services.count) services."
            )
        }

        func declared<Individual>(_ property: any RDFCore.Resource, of subject: SubjectTerm, as _: Individual.Type) -> [Individual] {
            let candidates = Self.vocabulary.compactMap { $0 as? Individual }
            return graph.iris(property, of: subject).compactMap(candidates.individual(denotedBy:))
        }
        func resources(_ property: any RDFCore.Resource, of subject: SubjectTerm) -> [RDFCore.Value] {
            graph.iris(property, of: subject).map { .individual(RDF.ResourceIndividual(iri: $0)) }
        }
        func namedGraphs(of collection: SubjectTerm) -> [any ServiceDescription.NamedGraph] {
            graph.objects(ServiceDescription.namedGraph, of: collection).compactMap(\.subject).map { node in
                let namedGraph = ServiceDescription.NamedGraphIndividual(iri: node.iri)
                namedGraph.name = resources(ServiceDescription.name, of: node)
                namedGraph.entailmentRegime = declared(ServiceDescription.entailmentRegime, of: node, as: (any ServiceDescription.EntailmentRegime).self)
                return namedGraph
            }
        }

        let service = ServiceDescription.ServiceIndividual(iri: node.iri)
        service.endpoint = resources(ServiceDescription.endpoint, of: node)
        service.supportedLanguage = declared(ServiceDescription.supportedLanguage, of: node, as: (any ServiceDescription.Language).self)
        service.feature = declared(ServiceDescription.feature, of: node, as: (any ServiceDescription.Feature).self)
        service.languageExtension = declared(ServiceDescription.languageExtension, of: node, as: (any ServiceDescription.Feature).self)
        service.propertyFeature = declared(ServiceDescription.propertyFeature, of: node, as: (any ServiceDescription.Feature).self)
        service.resultFormat = declared(ServiceDescription.resultFormat, of: node, as: (any Formats.Format).self)
        service.inputFormat = declared(ServiceDescription.inputFormat, of: node, as: (any Formats.Format).self)
        service.defaultEntailmentRegime = declared(
            ServiceDescription.defaultEntailmentRegime, of: node, as: (any ServiceDescription.EntailmentRegime).self
        )
        service.defaultDataset = graph.objects(ServiceDescription.defaultDataset, of: node).compactMap(\.subject).map { node in
            let dataset = ServiceDescription.DatasetIndividual(iri: node.iri)
            dataset.namedGraph = namedGraphs(of: node)
            return dataset
        }
        service.availableGraphs = graph.objects(ServiceDescription.availableGraphs, of: node).compactMap(\.subject).map { node in
            let collection = ServiceDescription.GraphCollectionIndividual(iri: node.iri)
            collection.namedGraph = namedGraphs(of: node)
            return collection
        }
        return service
    }
}
