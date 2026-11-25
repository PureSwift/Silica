// swift-tools-version:6.1
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
            name: "SilicaQuartz",
            targets: ["SilicaQuartz"]
        ),
        .library(
            name: "Silica3DS",
            targets: ["Silica3DS"]
        ),
        .library(
            name: "SilicaWeb",
            targets: ["SilicaWeb"]
        ),
        // For trying the C API locally: the installed library is CMake's
        // libCoreGraphics, built from the same targets.
        .library(
            name: "SilicaCoreGraphicsABI",
            type: .dynamic,
            targets: ["SilicaCoreGraphicsABI"]
        ),
        // The drawings every backend's tests render, for backends in other
        // packages (AndroidSilica, in PureSwift/Android).
        .library(
            name: "SilicaTestSupport",
            targets: ["SilicaTestSupport"]
        )
    ],
    traits: [
        // Builds SilicaCairo's renderer, with the Cairo and FontConfig packages.
        .trait(name: "Cairo"),
        // Builds SilicaWeb's renderer, with JavaScriptKit.
        .trait(name: "Web"),
        // A package that needs only the `Silica` module can turn both off
        // (`traits: []`), and those packages aren't fetched.
        .default(enabledTraits: ["Cairo", "Web"])
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
                    condition: .when(platforms: [.macOS, .linux], traits: ["Cairo"])
                ),
                .product(
                    name: "FontConfig",
                    package: "FontConfig",
                    condition: .when(platforms: [.macOS, .linux], traits: ["Cairo"])
                )
            ],
            exclude: ["CMakeLists.txt"]
        ),
        .target(
            name: "SilicaQuartz",
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
                    condition: .when(platforms: [.wasi], traits: ["Web"])
                )
            ]
        ),
        // CoreGraphics' C API, drawn by Silica: the headers, constants and stubs
        // in C, the functions in Swift. CMake builds it as libCoreGraphics.
        .target(
            name: "CSilicaCoreGraphics",
            exclude: ["CMakeLists.txt", "CoreGraphics.modulemap"]
        ),
        .target(
            name: "SilicaCoreGraphicsABI",
            dependencies: [
                "Silica",
                "CSilicaCoreGraphics",
                // contexts draw with Cairo
                "SilicaCairo",
                .product(
                    name: "Cairo",
                    package: "Cairo",
                    condition: .when(platforms: [.linux], traits: ["Cairo"])
                )
            ],
            exclude: ["CMakeLists.txt"]
        ),
        .target(
            name: "SilicaTestSupport",
            dependencies: ["Silica"],
            path: "Tests/SilicaTestSupport"
        ),
        .testTarget(
            name: "SilicaTests",
            dependencies: ["Silica"]
        ),
        .testTarget(
            name: "SilicaCairoTests",
            dependencies: [
                "SilicaCairo",
                "SilicaTestSupport"
            ]
        ),
        .testTarget(
            name: "SilicaQuartzTests",
            dependencies: [
                "SilicaQuartz",
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
