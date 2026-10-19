// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Barnacles",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Barnacles", path: "Sources/Barnacles"),
    ]
)
