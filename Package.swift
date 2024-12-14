// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Silica",
    products: [
        .library(
            name: "Silica",
            targets: ["Silica"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/PureSwift/Cairo.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/PureSwift/FontConfig.git",
            branch: "master"
        )
    ],
    targets: [
        .target(
            name: "Silica",
            dependencies: [
                "Cairo",
                "FontConfig"
            ]
        ),
        .testTarget(
            name: "SilicaTests",
            dependencies: ["Silica"]
        )
    ]
)
