// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Tuuli",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0"),
        .package(url: "https://github.com/gabry-ts/partiti-ui", from: "0.2.0"),
    ],
    targets: [
        .target(
            name: "TuuliCore",
            path: "Sources/TuuliCore"
        ),
        .executableTarget(
            name: "Tuuli",
            dependencies: [
                "TuuliCore",
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "PartitiUI", package: "partiti-ui"),
            ],
            path: "Sources/Tuuli",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
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
