// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Tuuli",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "TuuliCore",
            path: "Sources/TuuliCore"
        ),
        .executableTarget(
            name: "Tuuli",
            dependencies: ["TuuliCore"],
            path: "Sources/Tuuli"
        ),
        .executableTarget(
            name: "TuuliHelper",
            dependencies: ["TuuliCore"],
            path: "Sources/TuuliHelper"
        ),
        .testTarget(
            name: "TuuliCoreTests",
            dependencies: ["TuuliCore"],
            path: "Tests/TuuliCoreTests"
        ),
    ]
)
