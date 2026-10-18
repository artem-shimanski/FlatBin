// swift-tools-version: 6.4

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "FlatBin",
    platforms: [.macOS(.v26)],
    products: [
        .library(
            name: "FlatBin",
            targets: ["FlatBin"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        .target(
            name: "FlatBin",
            dependencies: ["FlatBinMacros"],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        ),
        .macro(
            name: "FlatBinMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .testTarget(
            name: "FlatBinTests",
            dependencies: ["FlatBin"],
            swiftSettings: [
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("BorrowingSwitch"),
                .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
