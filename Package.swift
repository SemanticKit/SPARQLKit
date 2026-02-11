// swift-tools-version: 6.2

import PackageDescription

let strictSettings: [SwiftSetting] = [
    .unsafeFlags(["-strict-concurrency=complete"], .when(configuration: .debug)),
    .unsafeFlags(["-warnings-as-errors"])
]

let package = Package(
    name: "SPARQLKit",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "SPARQLKit",
            type: .dynamic,
            targets: ["SPARQLKit"]
        )
    ],
    dependencies: [
        .package(path: "../SemanticKit"),
        .package(path: "../RDFKit")
    ],
    targets: [
        .target(
            name: "SPARQLKit",
            dependencies: ["SemanticKit", "RDFKit"],
            path: "SPARQLKit",
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "SPARQLKitTests",
            dependencies: ["SPARQLKit"],
            path: "SPARQLKitTests",
            resources: [.process("Fixtures")],
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "SPARQLKitIntegrationTests",
            dependencies: ["SPARQLKit"],
            swiftSettings: strictSettings
        )
    ]
)
