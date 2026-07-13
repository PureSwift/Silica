// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Silica",
    products: [
        .library(
            name: "Silica",
            targets: ["Silica"]
        ),
        .library(
            name: "SilicaCairo",
            targets: ["SilicaCairo"]
        ),
        .library(
            name: "SilicaCoreGraphics",
            targets: ["SilicaCoreGraphics"]
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
            name: "Silica"
        ),
        .target(
            name: "SilicaCairo",
            dependencies: [
                "Silica",
                .product(
                    name: "Cairo",
                    package: "Cairo",
                    condition: .when(platforms: [.macOS, .linux])
                ),
                .product(
                    name: "FontConfig",
                    package: "FontConfig",
                    condition: .when(platforms: [.macOS, .linux])
                )
            ]
        ),
        .target(
            name: "SilicaCoreGraphics",
            dependencies: ["Silica"]
        ),
        .target(
            name: "SilicaTestSupport",
            dependencies: ["Silica"],
            path: "Tests/SilicaTestSupport"
        ),
        .testTarget(
            name: "SilicaCairoTests",
            dependencies: [
                "SilicaCairo",
                "SilicaTestSupport"
            ]
        ),
        .testTarget(
            name: "SilicaCoreGraphicsTests",
            dependencies: [
                "SilicaCoreGraphics",
                "SilicaCairo",
                "SilicaTestSupport"
            ]
        )
    ]
)
