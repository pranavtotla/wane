// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Wane",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Wane", targets: ["Wane"])
    ],
    targets: [
        .executableTarget(
            name: "Wane",
            path: "Sources/Wane",
            resources: [
                .copy("Resources/Info.plist")
            ]
        ),
        .testTarget(
            name: "WaneTests",
            dependencies: ["Wane"],
            path: "Tests/WaneTests"
        )
    ]
)
