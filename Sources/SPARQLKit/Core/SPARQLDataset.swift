import Foundation

public struct SPARQLDataset: Hashable, Sendable {
    public let defaultGraphs: [IRI]
    public let namedGraphs: [IRI]
    public let usingGraphs: [IRI]
    public let usingNamedGraphs: [IRI]

    public init(
        defaultGraphs: [IRI] = [],
        namedGraphs: [IRI] = [],
        usingGraphs: [IRI] = [],
        usingNamedGraphs: [IRI] = []
    ) {
        self.defaultGraphs = defaultGraphs
        self.namedGraphs = namedGraphs
        self.usingGraphs = usingGraphs
        self.usingNamedGraphs = usingNamedGraphs
    }

    public var defaultGraphURIs: [String] {
        defaultGraphs.map(\.string)
    }

    public var namedGraphURIs: [String] {
        namedGraphs.map(\.string)
    }

    public var usingGraphURIs: [String] {
        usingGraphs.map(\.string)
    }

    public var usingNamedGraphURIs: [String] {
        usingNamedGraphs.map(\.string)
    }
}
