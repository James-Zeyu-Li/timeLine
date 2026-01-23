// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimeLineCore",
    platforms: [.iOS("26.0"), .macOS("16.0")],
    products: [
        .library(
            name: "TimeLineCore",
            type: .dynamic,
            targets: ["TimeLineCore"]),
    ],
    targets: [
        .target(
            name: "TimeLineCore"),
        .testTarget(
            name: "TimeLineCoreTests",
            dependencies: ["TimeLineCore"]),
    ]
)
