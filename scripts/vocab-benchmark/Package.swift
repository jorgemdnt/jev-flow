// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "VocabBench",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", revision: "3fc97306612d119337c487ce789c6cd631a7876b", traits: []),
    ],
    targets: [
        .executableTarget(name: "VocabBench", dependencies: [.product(name: "FluidAudio", package: "FluidAudio")]),
    ]
)
