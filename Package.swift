// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LegadoReaderCore",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "LegadoReaderCore",
            targets: ["LegadoReaderCore"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LegadoReaderCore",
            path: "LegadoReader",
            exclude: [
                "Preview Content/",
                "Views/",
                "Info.plist",
                "LegadoReader.entitlements",
                "LegadoReaderApp.swift",
                "ContentView.swift"
            ],
            sources: [
                "Services/",
                "Models/",
                "ViewModels/"
            ]
        ),
        .executableTarget(
            name: "LegadoReaderTests",
            dependencies: ["LegadoReaderCore"],
            path: ".",
            sources: ["run_tests.swift"]
        ),
        .testTarget(
            name: "LegadoReaderCoreTests",
            dependencies: ["LegadoReaderCore"]
        ),
    ]
)
