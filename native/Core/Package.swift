// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SujiCore",
    platforms: [.macOS(.v14), .iOS("18.0")],
    products: [.library(name: "SujiCore", targets: ["SujiCore"])],
    targets: [
        .target(name: "SujiCore"),
        .executableTarget(name: "ReadingEvalFixtures", dependencies: ["SujiCore"], path: "Tools/ReadingEvalFixtures"),
        .testTarget(name: "SujiCoreTests", dependencies: ["SujiCore"])
    ]
)
