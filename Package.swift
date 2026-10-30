// swift-tools-version: 6.4

import PackageDescription

/// The products of RDFKit a translated vocabulary is built on: the RDF,
/// RDF Schema and OWL 2 layers, and the runtime their Swift uses.
let layers: [Target.Dependency] = [
    .product(name: "RDFCore", package: "RDFKit"),
    .product(name: "RDF", package: "RDFKit"),
    .product(name: "OWL", package: "RDFKit")
]

/// RDF in, Swift out: each vocabulary target is the published RDF of its
/// vocabulary, which RDFKit's translator turns into the Swift it describes on
/// every build.
let translated: [Target.PluginUsage] = [.plugin(name: "RDFTranslatorPlugin", package: "RDFKit")]

let package = Package(
    name: "SPARQLKit",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .visionOS(.v27)
    ],
    products: [
        .library(
            name: "SPARQLKit",
            targets: ["SPARQLKit", "ServiceDescription", "Formats", "EntailmentRegimes", "FOAF"]
        ),
        .library(
            name: "SPARQLConformance",
            targets: ["SPARQLConformance", "TestManifest", "TestQuery", "TestUpdate"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/SemanticKit/IRIKit.git", branch: "main"),
        .package(url: "https://github.com/SemanticKit/RDFKit.git", branch: "main")
    ],
    targets: [
        .target(
            name: "SPARQLKit",
            dependencies: [
                "ServiceDescription",
                "Formats",
                "EntailmentRegimes",
                "SPARQLConformance",
                "TestManifest",
                "TestQuery",
                "TestUpdate",
                .product(name: "IRIKit", package: "IRIKit"),
                .product(name: "RDFFormats", package: "RDFKit")
            ] + layers
        ),

        // The vocabularies SPARQL services are described in, and FOAF, which
        // the documents of the formats and entailment regimes describe their
        // author in.
        .target(name: "FOAF", dependencies: layers, plugins: translated),
        .target(name: "Formats", dependencies: ["FOAF"] + layers, plugins: translated),
        .target(name: "ServiceDescription", dependencies: ["Formats"] + layers, plugins: translated),
        .target(
            name: "EntailmentRegimes",
            dependencies: ["ServiceDescription", "FOAF"] + layers,
            plugins: translated
        ),

        // The vocabularies conformance manifests are written in.
        .target(name: "TestManifest", dependencies: layers, plugins: translated),
        .target(name: "TestQuery", dependencies: layers, plugins: translated),
        .target(name: "TestUpdate", dependencies: layers, plugins: translated),
        .target(
            name: "SPARQLConformance",
            dependencies: ["TestManifest", "TestQuery", "TestUpdate"] + layers,
            plugins: translated
        ),

        // The fixture reading both test targets share.
        .target(
            name: "SPARQLKitTestSupport",
            dependencies: [
                "ServiceDescription",
                .product(name: "IRIKit", package: "IRIKit"),
                .product(name: "RDFFormats", package: "RDFKit")
            ] + layers,
            path: "Tests/SPARQLKitTestSupport"
        ),
        .testTarget(
            name: "SPARQLKitTests",
            dependencies: [
                "SPARQLKit",
                "SPARQLKitTestSupport",
                "ServiceDescription",
                "Formats",
                "EntailmentRegimes",
                "FOAF",
                "SPARQLConformance",
                "TestManifest",
                "TestQuery",
                "TestUpdate",
                .product(name: "IRIKit", package: "IRIKit"),
                .product(name: "RDFFormats", package: "RDFKit")
            ] + layers,
            resources: [.process("Fixtures")]
        ),
        .testTarget(
            name: "SPARQLKitIntegrationTests",
            dependencies: [
                "SPARQLKit",
                "SPARQLKitTestSupport",
                "ServiceDescription",
                "Formats",
                "EntailmentRegimes",
                "FOAF",
                .product(name: "IRIKit", package: "IRIKit"),
                .product(name: "RDFFormats", package: "RDFKit")
            ] + layers,
            resources: [.process("Fixtures")]
        ),
    ]
)
