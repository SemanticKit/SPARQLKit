import Foundation
import IRIKit
import RDFCore
import RDFFormats
import ServiceDescription

/// A fixture file of a test target, and, for a Turtle fixture, the graph it
/// states, decoded by RDFFormats' ``TurtleDecoder``.
///
/// Tests read the terms they use from what the graph states, by meaning: the
/// objects of a property, the nodes that have one, the graphs a dataset
/// description names (SPARQL 1.2 Service Description §3.2). No IRI is typed in
/// Swift, and no term is read by its position in a triple.
public struct Fixture {
    /// The graph the fixture states.
    public let graph: RDFCore.Graph

    /// The fixture `fileName` among the resources of `bundle` (the test
    /// target's `Bundle.module`).
    public init(_ fileName: String, in bundle: Bundle) throws {
        graph = try TurtleDecoder().decode(String(decoding: try Fixture.data(fileName, in: bundle), as: UTF8.self))
    }

    /// The graph a document the test holds inline states.
    public init(graph: RDFCore.Graph) {
        self.graph = graph
    }

    /// The bytes of the fixture file `fileName` among the resources of
    /// `bundle`.
    public static func data(_ fileName: String, in bundle: Bundle) throws -> Data {
        let file = URL(fileURLWithPath: fileName)
        guard let url = bundle.url(forResource: file.deletingPathExtension().lastPathComponent, withExtension: file.pathExtension) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: fileName])
        }
        return try Data(contentsOf: url)
    }

    /// The IRIs the fixture states as values of `property`, in IRI order.
    public func iris(_ property: any RDFCore.Resource) -> [IRI] {
        graph.compactMap { $0.predicate == IRI(of: property) ? named($0.object) : nil }.sorted { $0.rawValue < $1.rawValue }
    }

    /// The one IRI the fixture states as a value of `property`.
    public func iri(_ property: any RDFCore.Resource) throws -> IRI {
        try Fixture.one(iris(property), "value of \(property)")
    }

    /// The one node, named by an IRI, the fixture states has `property`.
    public func subject(_ property: any RDFCore.Resource) throws -> IRI {
        let subjects = Set(graph.compactMap { $0.predicate == IRI(of: property) ? named($0.subject) : nil })
        return try Fixture.one(Array(subjects), "subject of \(property)")
    }

    /// The one triple the fixture states with the predicate `property`.
    public func triple(_ property: any RDFCore.Resource) throws -> RDFCore.Graph.Element {
        try Fixture.one(graph.filter { $0.predicate == IRI(of: property) }, "triple of \(property)")
    }

    /// The one triple the fixture states.
    public func triple() throws -> RDFCore.Graph.Element {
        try Fixture.one(Array(graph), "triple")
    }

    /// The default graphs the fixture's dataset descriptions state
    /// (`sd:defaultGraph`), in IRI order.
    public var defaultGraphs: [IRI] { iris(ServiceDescription.defaultGraph) }

    /// The names (`sd:name`) of the named graphs the fixture's dataset
    /// descriptions state (`sd:namedGraph`), in IRI order.
    public var namedGraphs: [IRI] {
        let graphs = Set(graph.compactMap { $0.predicate == IRI(of: ServiceDescription.namedGraph) ? $0.object.subject : nil })
        return graph.compactMap { triple in
            triple.predicate == IRI(of: ServiceDescription.name) && graphs.contains(triple.subject) ? named(triple.object) : nil
        }.sorted { $0.rawValue < $1.rawValue }
    }

    /// The one named graph the fixture's dataset description names.
    public func namedGraph() throws -> IRI {
        try Fixture.one(namedGraphs, "named graph")
    }

    static func one<Element>(_ elements: [Element], _ what: String) throws -> Element {
        guard elements.count == 1, let element = elements.first else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "The fixture states \(elements.count) of \(what), not one."))
        }
        return element
    }
}

/// The IRI `term` is, or `nil` for any other term.
func named(_ term: ObjectTerm) -> IRI? {
    if case .iri(let iri) = term { return iri }
    return nil
}

/// The IRI that names the node `term`, or `nil` for a blank node.
func named(_ term: SubjectTerm) -> IRI? {
    if case .iri(let iri) = term { return iri }
    return nil
}

extension RDFCore.Graph.Element {
    /// The IRI that names the triple's subject.
    public var subjectIRI: IRI? { named(subject) }

    /// The IRI the triple's object is.
    public var objectIRI: IRI? { named(object) }
}
