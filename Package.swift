// swift-tools-version:6.0
// MarbleAgent: a photo filter on the GPU, as a Granite agent package. An app that links it finds the
// `marble` agent through Granite's roster, with nothing listed by hand.

import PackageDescription

let package = Package(
    name: "MarbleAgent",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MarbleAgent", targets: ["MarbleAgent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/riteshpakala/Granite.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "MarbleAgent",
            dependencies: [.product(name: "GraniteAgents", package: "Granite")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "MarbleAgentTests",
            dependencies: ["MarbleAgent", .product(name: "GraniteAgents", package: "Granite")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
