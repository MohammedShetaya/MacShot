// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacShot",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacShot",
            path: "Sources/MacShot",
            exclude: ["Info.plist", "MacShot.entitlements"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("CoreImage"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(
            name: "MacShotTests",
            dependencies: ["MacShot"],
            path: "Tests/MacShotTests"
        ),
    ]
)
