import Foundation
import IRIKit

public struct SPARQLFederatedBindingAnalysis: Hashable, Sendable {
    public let localVariables: Set<Variable>
    public let serviceVariablesByEndpoint: [String: Set<Variable>]
    public let propagatedVariables: Set<Variable>
    public let serviceOnlyVariables: Set<Variable>

    public init(
        localVariables: Set<Variable>,
        serviceVariablesByEndpoint: [String: Set<Variable>],
        propagatedVariables: Set<Variable>,
        serviceOnlyVariables: Set<Variable>
    ) {
        self.localVariables = localVariables
        self.serviceVariablesByEndpoint = serviceVariablesByEndpoint
        self.propagatedVariables = propagatedVariables
        self.serviceOnlyVariables = serviceOnlyVariables
    }
}

public struct SPARQLServiceClause: Hashable, Sendable {
    public let endpointIRI: String
    public let patterns: [String]
    public let silent: Bool

    public init(endpointIRI: String, patterns: [String], silent: Bool = false) {
        self.endpointIRI = endpointIRI
        self.patterns = patterns
        self.silent = silent
    }

    public func render() -> String {
        var lines: [String] = []
        let silentToken = silent ? "SILENT " : ""
        lines.append("SERVICE \(silentToken)<\(endpointIRI)> {")
        for pattern in patterns {
            lines.append("  \(pattern)")
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }
}

public struct SPARQLFederatedSelectQuery: Hashable, Sendable, SPARQLQueryRenderable {
    public var prefixes: [String: IRI]
    public var variables: [Variable]
    public var localPatterns: [String]
    public var serviceClauses: [SPARQLServiceClause]
    public var limit: Int?

    public init(
        prefixes: [String: IRI] = [:],
        variables: [Variable],
        localPatterns: [String] = [],
        serviceClauses: [SPARQLServiceClause],
        limit: Int? = nil
    ) {
        self.prefixes = prefixes
        self.variables = variables
        self.localPatterns = localPatterns
        self.serviceClauses = serviceClauses
        self.limit = limit
    }

    public func render() -> String {
        var lines: [String] = []
        for key in prefixes.keys.sorted() {
            if let iri = prefixes[key] {
                lines.append("PREFIX \(key): <\(iri.rawValue)>")
            }
        }

        lines.append("SELECT \(variables.map(\.sparql).joined(separator: " "))")
        lines.append("WHERE {")

        for pattern in localPatterns {
            lines.append("  \(pattern)")
        }

        for clause in serviceClauses {
            let rendered = clause.render().split(separator: "\n", omittingEmptySubsequences: false)
            for line in rendered {
                lines.append("  \(line)")
            }
        }

        lines.append("}")

        if let limit {
            lines.append("LIMIT \(limit)")
        }

        return lines.joined(separator: "\n")
    }

    public func bindingAnalysis() -> SPARQLFederatedBindingAnalysis {
        let localVariables = extractVariables(from: localPatterns)
        var serviceVariablesByEndpoint: [String: Set<Variable>] = [:]
        var allServiceVariables: Set<Variable> = []

        for clause in serviceClauses {
            let variables = extractVariables(from: clause.patterns)
            serviceVariablesByEndpoint[clause.endpointIRI, default: []].formUnion(variables)
            allServiceVariables.formUnion(variables)
        }

        let propagated = localVariables.intersection(allServiceVariables)
        let serviceOnly = allServiceVariables.subtracting(localVariables)

        return SPARQLFederatedBindingAnalysis(
            localVariables: localVariables,
            serviceVariablesByEndpoint: serviceVariablesByEndpoint,
            propagatedVariables: propagated,
            serviceOnlyVariables: serviceOnly
        )
    }

    private func extractVariables(from patterns: [String]) -> Set<Variable> {
        var result: Set<Variable> = []
        let regex = try? NSRegularExpression(pattern: #"\?[A-Za-z_][A-Za-z0-9_\-]*"#)
        for pattern in patterns {
            let nsrange = NSRange(pattern.startIndex ..< pattern.endIndex, in: pattern)
            let matches = regex?.matches(in: pattern, options: [], range: nsrange) ?? []
            for match in matches {
                if let range = Range(match.range, in: pattern) {
                    result.insert(Variable(rawValue: String(pattern[range])))
                }
            }
        }
        return result
    }
}
