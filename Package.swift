// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Silica",
    platforms: [
        .macOS(.v13)
    ],
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
        ),
        .library(
            name: "Silica3DS",
            targets: ["Silica3DS"]
        ),
        .library(
            name: "SilicaWeb",
            targets: ["SilicaWeb"]
        ),
        // The drawings every backend's tests render, for backends in other
        // packages (AndroidSilica, in PureSwift/Android).
        .library(
            name: "SilicaTestSupport",
            targets: ["SilicaTestSupport"]
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
        ),
        .package(
            url: "https://github.com/swiftwasm/JavaScriptKit.git",
            from: "0.56.1"
        )
    ],
    targets: [
        .target(
            name: "Silica",
            exclude: ["CMakeLists.txt"]
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
            ],
            exclude: ["CMakeLists.txt"]
        ),
        .target(
            name: "SilicaCoreGraphics",
            dependencies: ["Silica"],
            exclude: ["CMakeLists.txt"]
        ),
        .target(
            name: "Silica3DS",
            dependencies: ["Silica"]
        ),
        .target(
            name: "SilicaWeb",
            dependencies: [
                "Silica",
                .product(
                    name: "JavaScriptKit",
                    package: "JavaScriptKit",
                    condition: .when(platforms: [.wasi])
                )
            ]
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
        ),
        .testTarget(
            name: "Silica3DSTests",
            dependencies: [
                "Silica3DS",
                "SilicaTestSupport"
            ]
        )
    ]
)
