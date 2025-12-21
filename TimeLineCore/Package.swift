// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimeLineCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(
            name: "TimeLineCore",
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
