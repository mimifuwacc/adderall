// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Adderall",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Adderall",
            path: "Sources/Adderall"
        )
    ]
)
