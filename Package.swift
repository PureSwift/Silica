import PackageDescription

let package = Package(
    name: "Silica",
    dependencies: [
        .Package(url: "https://github.com/PureSwift/Cairo.git", majorVersion: 1)
    ],
    exclude: ["Xcode"]
)