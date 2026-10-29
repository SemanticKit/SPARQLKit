// swift-tools-version: 6.4

import PackageDescription

let strictSettings: [SwiftSetting] = [
    .unsafeFlags(["-strict-concurrency=complete"], .when(configuration: .debug))
]

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
        .package(url: "https://github.com/SemanticKit/RDFKit.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "SPARQLKit",
            dependencies: [
                .product(name: "IRIKit", package: "IRIKit"),
                .product(name: "RDFCore", package: "RDFKit"),
                .product(name: "RDFFormats", package: "RDFKit"),
                .product(name: "RDFKit", package: "RDFKit")
            ],
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "SPARQLKitTests",
            dependencies: [
                "SPARQLKit",
                .product(name: "IRIKit", package: "IRIKit"),
                .product(name: "RDFCore", package: "RDFKit")
            ],
            resources: [.process("Fixtures")],
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "SPARQLKitIntegrationTests",
            dependencies: [
                "SPARQLKit",
                .product(name: "IRIKit", package: "IRIKit"),
                .product(name: "RDFCore", package: "RDFKit")
            ],
            swiftSettings: strictSettings
        )
    ]
)
