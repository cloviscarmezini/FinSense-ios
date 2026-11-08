// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FinSense",
    defaultLocalization: "pt",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "FinSense",
            targets: ["FinSense"]
        )
    ],
    targets: [
        .target(
            name: "FinSense",
            path: "Sources/FinSense"
        ),
        .testTarget(
            name: "FinSenseTests",
            dependencies: ["FinSense"],
            path: "Tests/FinSenseTests"
        )
    ]
)
