// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "VesperKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Vault", targets: ["Vault"]),
        .library(name: "Identity", targets: ["Identity"]),
        .library(name: "Consumers", targets: ["Consumers"]),
        .library(name: "VesperMarkdown", targets: ["VesperMarkdown"]),
        .library(name: "VesperUI", targets: ["VesperUI"]),
        .library(name: "Social", targets: ["Social"]),
    ],
    dependencies: [
        // Vector-tile maps; the distribution ships an iOS-only binary.
        .package(url: "https://github.com/maplibre/maplibre-gl-native-distribution", exact: "6.31.0"),
    ],
    targets: [
        .target(name: "Vault"),
        .target(name: "Identity", dependencies: ["Vault"]),
        .target(name: "Consumers", dependencies: ["Identity"]),
        .target(name: "VesperMarkdown"),
        .target(
            name: "VesperUI",
            dependencies: [
                "VesperMarkdown",
                .product(name: "MapLibre", package: "maplibre-gl-native-distribution", condition: .when(platforms: [.iOS])),
            ]
        ),
        .target(name: "Social", dependencies: ["Consumers", "VesperMarkdown"]),
        .testTarget(name: "IdentityTests", dependencies: ["Identity", "Vault"]),
        .testTarget(name: "SocialTests", dependencies: ["Social"]),
        .testTarget(name: "ConsumersTests", dependencies: ["Consumers"]),
        .testTarget(name: "VesperMarkdownTests", dependencies: ["VesperMarkdown"]),
    ]
)
