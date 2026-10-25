// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PocketRepublicCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PocketRepublicCore", targets: ["PocketRepublicCore"])
    ],
    targets: [
        // Pure simulation. Must never import SwiftUI/SpriteKit/UIKit:
        // that is what keeps the renderer replaceable and lets this test on Linux CI.
        .target(name: "PocketRepublicCore"),
        .testTarget(name: "PocketRepublicCoreTests", dependencies: ["PocketRepublicCore"])
    ]
)
