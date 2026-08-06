// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "vaudeville",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "vaudeville", path: "Sources/vaudeville")
    ]
)
