// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "VHS", platforms: [.macOS(.v26)], products: [
    .executable(name: "VHS", targets: ["VHS"]),
    .library(name: "VHSPluginUI", type: .dynamic, targets: ["VHSPluginUI"])
], targets: [
    .executableTarget(name: "VHSPluginProbe", dependencies: ["VHSPluginUI"], swiftSettings: [.defaultIsolation(MainActor.self)]),
    .target(name: "VHSCore"),
    .target(name: "VHSGraphUI", dependencies: ["VHSCore"], swiftSettings: [.defaultIsolation(MainActor.self)]),
    .target(name: "VHSRealtime"),
    .target(name: "VHSPluginUI", dependencies: ["VHSCore", "VHSRenderer", "VHSRealtime", "VHSGraphUI"], swiftSettings: [.defaultIsolation(MainActor.self)]),
    .testTarget(name: "VHSRealtimeTests", dependencies: ["VHSRealtime"]),
    .target(name: "VHSRenderer", dependencies: ["VHSCore"], resources: [.copy("Shaders")]),
    .executableTarget(name: "VHS", dependencies: ["VHSCore", "VHSRenderer", "VHSGraphUI"], swiftSettings: [.defaultIsolation(MainActor.self)]),
    .testTarget(name: "VHSCoreTests", dependencies: ["VHSCore"]),
    .testTarget(name: "VHSRendererTests", dependencies: ["VHSCore", "VHSRenderer"])
])
