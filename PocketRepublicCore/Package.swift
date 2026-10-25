// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PocketRepublicCore",
    products: [
        .library(name: "PocketRepublicCore", targets: ["PocketRepublicCore"])
    ],
    targets: [
        .target(name: "PocketRepublicCore"),
        .testTarget(name: "PocketRepublicCoreTests", dependencies: ["PocketRepublicCore"])
    ]
)
