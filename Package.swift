// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuietControl",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "QuietControl", targets: ["QuietControl"])],
    targets: [
        .target(name: "QuietCore"),
        .executableTarget(name: "QuietControl", dependencies: ["QuietCore"],
                          linkerSettings: [.linkedFramework("IOBluetooth")]),
        .testTarget(name: "QuietCoreTests", dependencies: ["QuietCore", "QuietControl"])
    ]
)
