// swift-tools-version: 6.4

import PackageDescription

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
            targets: ["SPARQLKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/SemanticKit/IRIKit.git", branch: "main"),
        .package(url: "https://github.com/SemanticKit/RDFKit.git", branch: "wp/04-one-rdf-model")
    ],
    targets: [
        .target(
            name: "SPARQLKit",
            dependencies: [
                .product(name: "IRIKit", package: "IRIKit"),
                .product(name: "RDFCore", package: "RDFKit"),
                .product(name: "RDFFormats", package: "RDFKit"),
                .product(name: "RDFKit", package: "RDFKit")
            ]
        ),
        .testTarget(
            name: "SPARQLKitTests",
            dependencies: [
                "SPARQLKit",
                .product(name: "IRIKit", package: "IRIKit"),
                .product(name: "RDFCore", package: "RDFKit"),
                .product(name: "RDFFormats", package: "RDFKit"),
                .product(name: "RDFKit", package: "RDFKit")
            ],
            resources: [.process("Fixtures")]
        ),
        .testTarget(
            name: "SPARQLKitIntegrationTests",
            dependencies: [
                "SPARQLKit",
                .product(name: "IRIKit", package: "IRIKit"),
                .product(name: "RDFCore", package: "RDFKit"),
                .product(name: "RDFFormats", package: "RDFKit"),
                .product(name: "RDFKit", package: "RDFKit")
            ]
        )
    ]
)
