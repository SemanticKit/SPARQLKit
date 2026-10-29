import IRIKit

/// How the variables of a federated query are shared between the local
/// patterns and its `SERVICE` patterns (SPARQL 1.2 Federated Query §4).
public struct SPARQLFederatedBindingAnalysis: Hashable, Sendable {
    /// The variables of one `SERVICE` pattern.
    public struct Service: Hashable, Sendable {
        public let endpoint: IRI
        public let variables: Set<Variable>

        public init(endpoint: IRI, variables: Set<Variable>) {
            self.endpoint = endpoint
            self.variables = variables
        }
    }

    /// The variables the patterns outside every `SERVICE` bind.
    public let localVariables: Set<Variable>
    /// Each `SERVICE` pattern, in query order.
    public let services: [Service]
    /// The variables bound both locally and by a service.
    public let propagatedVariables: Set<Variable>
    /// The variables only services bind.
    public let serviceOnlyVariables: Set<Variable>

    public init(
        localVariables: Set<Variable>,
        services: [Service],
        propagatedVariables: Set<Variable>,
        serviceOnlyVariables: Set<Variable>
    ) {
        self.localVariables = localVariables
        self.services = services
        self.propagatedVariables = propagatedVariables
        self.serviceOnlyVariables = serviceOnlyVariables
    }
}
