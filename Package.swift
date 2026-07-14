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
            name: "SilicaAndroid",
            targets: ["SilicaAndroid"]
        ),
        .library(
            name: "Silica3DS",
            targets: ["Silica3DS"]
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
            url: "https://github.com/PureSwift/Android.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-java.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-android-sdk/swift-android-native.git",
            branch: "main"
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
            name: "SilicaAndroid",
            dependencies: [
                "Silica",
                .product(
                    name: "AndroidGraphics",
                    package: "Android",
                    condition: .when(platforms: [.android])
                ),
                .product(
                    name: "JavaIO",
                    package: "swift-java",
                    condition: .when(platforms: [.android])
                )
            ]
        ),
        .target(
            name: "Silica3DS",
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
        ),
        .testTarget(
            name: "Silica3DSTests",
            dependencies: [
                "Silica3DS",
                "SilicaTestSupport"
            ]
        ),
        .testTarget(
            name: "SilicaAndroidTests",
            dependencies: [
                "SilicaAndroid",
                "SilicaTestSupport",
                .product(
                    name: "AndroidApp",
                    package: "Android",
                    condition: .when(platforms: [.android])
                ),
                .product(
                    name: "AndroidContext",
                    package: "swift-android-native",
                    condition: .when(platforms: [.android])
                ),
                .product(
                    name: "SwiftJava",
                    package: "swift-java",
                    condition: .when(platforms: [.android])
                )
            ]
        )
    ]
)
