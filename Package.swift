// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FinderGroupExpander",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FinderGroupExpander", targets: ["FinderGroupExpander"])
    ],
    targets: [
        .executableTarget(
            name: "FinderGroupExpander",
            path: "Sources/FinderGroupExpander"
        )
    ]
)
