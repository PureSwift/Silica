// swift-tools-version:6.0
import Foundation
import PackageDescription

// SwiftPM has no manifest-time way to detect the Embedded Swift SDK, so
// building with `swift-*-RELEASE_wasm-embedded` requires setting this
// environment variable — see README.md.
let isEmbedded = ProcessInfo.processInfo.environment["SILICA_WASM_EMBEDDED"] != nil

let package = Package(
    name: "WebCanvasDemo",
    dependencies: [
        .package(name: "Silica", path: "../.."),
        .package(
            url: "https://github.com/swiftwasm/JavaScriptKit.git",
            from: "0.56.1"
        )
    ],
    targets: [
        .executableTarget(
            name: "WebCanvasDemo",
            dependencies: [
                .product(name: "SilicaWeb", package: "Silica"),
                "JavaScriptKit"
            ],
            linkerSettings: isEmbedded ? [
                // String comparison and hashing require the Unicode data
                // tables, which Embedded Swift does not link automatically.
                .linkedLibrary(
                    "swiftUnicodeDataTables",
                    .when(platforms: [.wasi])
                )
            ] : []
        )
    ],
    swiftLanguageModes: [.v5]
)
