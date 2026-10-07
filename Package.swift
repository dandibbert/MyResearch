// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyResearchCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(name: "MyResearchCore", targets: ["MyResearchCore"]),
        .library(name: "TranslationCore", targets: ["TranslationCore"]),
    ],
    targets: [
        .target(name: "TranslationCore", path: "TranslationCore"),
        .target(name: "MyResearchCore", dependencies: ["TranslationCore"], path: "Core"),
        .testTarget(name: "MyResearchCoreTests", dependencies: ["MyResearchCore", "TranslationCore"], path: "Tests/MyResearchCoreTests"),
        .testTarget(name: "TranslationCoreTests", dependencies: ["TranslationCore"], path: "Tests/TranslationCoreTests"),
    ],
    swiftLanguageVersions: [.v5]
)
