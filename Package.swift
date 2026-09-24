// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Kept",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "Kept", targets: ["Kept"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            from: "0.17.2",
            traits: []
        ),
    ],
    targets: [
        .executableTarget(
            name: "Kept",
            dependencies: [
                "KeptCore",
                .product(name: "FluidAudio", package: "FluidAudio"),
            ]
        ),
        .target(name: "KeptCore"),
        // Command Line Tools ship Swift Testing as a framework, but `swift test`
        // searches that directory with -I. The runner only imports Testing if
        // Testing.swiftmodule is in .build/.../Modules. scripts/link-testing-module.sh
        // plants that link. -F and -framework are what the test bundle itself needs.
        .testTarget(
            name: "KeptCoreTests",
            dependencies: ["KeptCore"],
            swiftSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                ]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-F",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-framework",
                    "-Xlinker", "Testing",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                ]),
            ]
        ),
    ]
)
