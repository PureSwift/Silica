import PackageDescription

let package = Package(
    name: "Silica",
    targets: [
        Target(name: "Silica")
    ],
    dependencies: [
        .Package(url: "https://github.com/PureSwift/Cairo.git", majorVersion: 1),
        .Package(url: "https://github.com/PureSwift/LittleCMS.git", majorVersion: 1)
    ]
)
