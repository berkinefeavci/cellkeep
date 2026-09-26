// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Cellkeep",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "PowerUIBridge", path: "Sources/PowerUIBridge", cSettings: [.unsafeFlags(["-fobjc-arc"])]),
        .executableTarget(
            name: "CellkeepNativeChargeHelper",
            dependencies: ["PowerUIBridge"],
            path: "Sources/NativeChargeHelper"
        ),
        .executableTarget(
            name: "Cellkeep",
            dependencies: ["PowerUIBridge"],
            path: "Sources/ChargeMate",
            resources: [.process("Resources")]
        )
    ]
)
