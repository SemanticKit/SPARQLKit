// swift-tools-version: 6.3

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
        .package(url: "https://github.com/SemanticKit/RDFKit.git", branch: "main"),
        .package(url: "https://github.com/SemanticKit/SemanticKit.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "SPARQLKit",
            dependencies: ["SemanticKit", "RDFKit"],
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "SPARQLKitTests",
            dependencies: ["SPARQLKit"],
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
