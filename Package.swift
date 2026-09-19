// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "MyResearchCore", platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "MyResearchCore", targets: ["MyResearchCore"])],
    targets: [.target(name: "MyResearchCore", path: "Core"),
              .testTarget(name: "MyResearchCoreTests", dependencies: ["MyResearchCore"], path: "Tests/MyResearchCoreTests")],
    swiftLanguageVersions: [.v5]
)
