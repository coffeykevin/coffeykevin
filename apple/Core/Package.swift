// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BananarcCore",
    products: [
        .library(name: "BananarcCore", targets: ["BananarcCore"])
    ],
    targets: [
        .target(name: "BananarcCore", path: "Sources/BananarcCore"),
        .testTarget(
            name: "BananarcCoreTests",
            dependencies: ["BananarcCore"],
            path: "Tests/BananarcCoreTests"
        ),
    ]
)
