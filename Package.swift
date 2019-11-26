// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Silica",
    products: [
        .library(name: "Silica", targets: ["Silica"])
    ],
    dependencies: [
        .package(url: "https://github.com/PureSwift/Cairo.git", .branch("master"))
    ],
    targets: [
        .target(name: "Silica", dependencies: ["Cairo"]),
        .testTarget(name: "SilicaTests", dependencies: ["Silica"])
    ]

)
