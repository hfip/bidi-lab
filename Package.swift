// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BidiLab",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(name: "BidiLab", targets: ["BidiLab"])
    ],
    targets: [
        .target(name: "BidiLab"),
        .testTarget(name: "BidiLabTests", dependencies: ["BidiLab"]),
    ]
)
