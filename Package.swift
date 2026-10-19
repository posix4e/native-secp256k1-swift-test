// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NativeSecp256k1",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NativeSecp256k1", targets: ["NativeSecp256k1"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "NativeSecp256k1"),
        .testTarget(
            name: "NativeSecp256k1Tests",
            dependencies: ["NativeSecp256k1"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
