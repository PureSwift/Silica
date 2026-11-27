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
        .trait(name: "Quartz"),
        .trait(name: "Nintendo3DS"),
        .default(enabledTraits: ["Cairo", "Quartz"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/PureSwift/Cairo.git",
            from: "1.4.0"
        ),
        .package(
            url: "https://github.com/PureSwift/FontConfig.git",
            from: "2.0.0"
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
                .target(name: "SilicaCairo", condition: .when(platforms: [.linux], traits: ["Cairo"])),
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
                .target(name: "SilicaCairo", condition: .when(traits: ["Cairo"])),
                "SilicaTestSupport"
            ]
        ),
        .testTarget(
            name: "SilicaQuartzTests",
            dependencies: [
                .target(name: "SilicaQuartz", condition: .when(traits: ["Quartz"])),
                .target(name: "SilicaCairo", condition: .when(traits: ["Cairo"])),
                "SilicaTestSupport"
            ]
        ),
        .testTarget(
            name: "Silica3DSTests",
            dependencies: [
                .target(name: "Silica3DS", condition: .when(traits: ["Nintendo3DS"])),
                "SilicaTestSupport"
            ]
        ),
        .testTarget(
            name: "SilicaCoreGraphicsABITests",
            dependencies: [
                "SilicaCoreGraphicsABI",
                "CSilicaCoreGraphics"
            ]
        )
    ]
)
