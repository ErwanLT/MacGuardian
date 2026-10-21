// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacGuardian",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MacGuardian", targets: ["MacGuardian"]),
    ],
    targets: [
        // Logique pure (machine à états, filtrage, traces) : aucune dépendance à Core Bluetooth ni à AppKit.
        .target(name: "MacGuardianCore"),
        .executableTarget(
            name: "MacGuardian",
            dependencies: ["MacGuardianCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "MacGuardianCoreTests", dependencies: ["MacGuardianCore"]),
    ]
)
