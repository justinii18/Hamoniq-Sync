// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HarmoniqSyncKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "HarmoniqSyncKit",
            targets: ["HarmoniqSyncKit"]
        ),
    ],
    dependencies: [
        // No external dependencies - using system frameworks
    ],
    targets: [
        // Swift wrapper target
        .target(
            name: "HarmoniqSyncKit",
            dependencies: [],
            path: "Sources",
            exclude: [
                "Package.swift"
            ],
            publicHeadersPath: "HarmoniqSyncKit/include",
            linkerSettings: [
                .linkedFramework("Accelerate"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedLibrary("c++"),
                .unsafeFlags(["-L../../HarmoniqSyncCore/build", "-lHarmoniqSyncCore"])
            ]
        ),
        
        // Test target
        .testTarget(
            name: "HarmoniqSyncKitTests",
            dependencies: ["HarmoniqSyncKit"],
            path: "Tests"
        ),
    ]
)