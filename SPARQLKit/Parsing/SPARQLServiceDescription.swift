import Foundation
import SemanticKit
import RDFKit

public struct SPARQLServiceDescription: Hashable, Sendable {
    public let endpoints: Set<String>
    public let supportedLanguages: Set<String>
    public let features: Set<String>
    public let resultFormats: Set<String>
    public let entailmentRegimes: Set<String>

    public init(
        endpoints: Set<String> = [],
        supportedLanguages: Set<String> = [],
        features: Set<String> = [],
        resultFormats: Set<String> = [],
        entailmentRegimes: Set<String> = []
    ) {
        self.endpoints = endpoints
        self.supportedLanguages = supportedLanguages
        self.features = features
        self.resultFormats = resultFormats
        self.entailmentRegimes = entailmentRegimes
    }

    public func supports(_ accept: SPARQLAccept) -> Bool {
        if resultFormats.isEmpty {
            return true
        }
        let canonical = Self.canonicalResultFormats(resultFormats)
        return canonical.contains(accept.rawValue)
    }

    public func supports(_ accept: SPARQLGraphAccept) -> Bool {
        if resultFormats.isEmpty {
            return true
        }
        let canonical = Self.canonicalResultFormats(resultFormats)
        return canonical.contains(accept.rawValue)
    }

    public func supportsEntailment(_ regimeIRI: String) -> Bool {
        entailmentRegimes.isEmpty || entailmentRegimes.contains(regimeIRI)
    }

    private static func canonicalResultFormats(_ formats: Set<String>) -> Set<String> {
        var normalized: Set<String> = []
        for format in formats {
            normalized.insert(format)
            if let media = formatIRIMapping[format] {
                normalized.insert(media)
            }
        }
        return normalized
    }

    private static let formatIRIMapping: [String: String] = [
        "http://www.w3.org/ns/formats/SPARQL_Results_JSON": SPARQLAccept.jsonResults.rawValue,
        "http://www.w3.org/ns/formats/SPARQL_Results_XML": SPARQLAccept.xmlResults.rawValue,
        "http://www.w3.org/ns/formats/SPARQL_Results_CSV": SPARQLAccept.csv.rawValue,
        "http://www.w3.org/ns/formats/SPARQL_Results_TSV": SPARQLAccept.tsv.rawValue,
        "http://www.w3.org/ns/formats/Turtle": SPARQLGraphAccept.turtle.rawValue,
        "http://www.w3.org/ns/formats/N-Triples": SPARQLGraphAccept.ntriples.rawValue,
        "http://www.w3.org/ns/formats/RDF_XML": SPARQLGraphAccept.rdfXML.rawValue,
        "http://www.w3.org/ns/formats/JSON-LD": SPARQLGraphAccept.jsonLD.rawValue
    ]
}

public struct SPARQLServiceDescriptionParser: Sendable {
    public init() {}

    public func parseTurtle(_ turtle: String) throws -> SPARQLServiceDescription {
        let graph = try Graph(turtle: turtle)

        var endpoints: Set<String> = []
        var supportedLanguages: Set<String> = []
        var features: Set<String> = []
        var resultFormats: Set<String> = []
        var entailmentRegimes: Set<String> = []

        for triple in graph.triples {
            let predicate = triple.predicate.string
            switch predicate {
            case "http://www.w3.org/ns/sparql-service-description#endpoint":
                if let value = iriString(from: triple.object) {
                    endpoints.insert(value)
                }
            case "http://www.w3.org/ns/sparql-service-description#supportedLanguage":
                if let value = iriString(from: triple.object) {
                    supportedLanguages.insert(value)
                }
            case "http://www.w3.org/ns/sparql-service-description#feature":
                if let value = iriString(from: triple.object) {
                    features.insert(value)
                }
            case "http://www.w3.org/ns/sparql-service-description#resultFormat":
                if let value = iriString(from: triple.object) {
                    resultFormats.insert(value)
                }
            case "http://www.w3.org/ns/sparql-service-description#entailmentRegime":
                if let value = iriString(from: triple.object) {
                    entailmentRegimes.insert(value)
                }
            default:
                continue
            }
        }

        return SPARQLServiceDescription(
            endpoints: endpoints,
            supportedLanguages: supportedLanguages,
            features: features,
            resultFormats: resultFormats,
            entailmentRegimes: entailmentRegimes
        )
    }

    private func iriString(from object: RDFTerm) -> String? {
        (object.node as? IRI)?.string
    }
}
