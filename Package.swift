// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "VHS", platforms: [.macOS(.v26)], products: [
    .executable(name: "VHS", targets: ["VHS"]),
    .library(name: "VHSInput", targets: ["VHSInput"]),
    .library(name: "VHSPluginUI", type: .dynamic, targets: ["VHSPluginUI"])
], targets: [
    .executableTarget(name: "VHSPluginProbe", dependencies: ["VHSPluginUI"], swiftSettings: [.defaultIsolation(MainActor.self)]),
    .target(name: "VHSCore"),
    .target(name: "VHSSignal", resources: [.copy("Resources/tokens.json")], swiftSettings: [.defaultIsolation(MainActor.self)]),
    .testTarget(name: "VHSSignalTests", dependencies: ["VHSSignal", "VHSCore"]),
    .target(name: "VHSGraphUI", dependencies: ["VHSCore", "VHSSignal"], swiftSettings: [.defaultIsolation(MainActor.self)]),
    .target(name: "VHSRealtime"),
    .target(name: "VHSInput", dependencies: ["VHSRealtime"]),
    .testTarget(name: "VHSInputTests", dependencies: ["VHSInput", "VHSRealtime"]),
    .target(name: "VHSDeviceIO", dependencies: ["VHSRealtime"], linkerSettings: [.linkedFramework("CoreAudio"), .linkedFramework("AudioToolbox"), .linkedFramework("CoreMIDI")]),
    .target(name: "VHSSystemIO", dependencies: ["VHSRealtime"], cSettings: [.unsafeFlags(["-fobjc-arc"])], linkerSettings: [.linkedFramework("ScreenCaptureKit"), .linkedFramework("CoreMedia")]),
    .target(name: "VHSDevices", dependencies: ["VHSInput", "VHSDeviceIO", "VHSRealtime", "VHSSystemIO"]),
    .testTarget(name: "VHSDevicesTests", dependencies: ["VHSDevices", "VHSDeviceIO", "VHSInput", "VHSRealtime", "VHSSystemIO"]),
    .target(name: "VHSPluginUI", dependencies: ["VHSCore", "VHSRenderer", "VHSRealtime", "VHSGraphUI", "VHSSignal"], swiftSettings: [.defaultIsolation(MainActor.self)]),
    .testTarget(name: "VHSRealtimeTests", dependencies: ["VHSRealtime"]),
    .target(name: "VHSRenderer", dependencies: ["VHSCore"], resources: [.copy("Shaders")]),
    .executableTarget(name: "VHS", dependencies: ["VHSCore", "VHSRenderer", "VHSGraphUI", "VHSSignal", "VHSDevices", "VHSInput"], swiftSettings: [.defaultIsolation(MainActor.self)]),
    .testTarget(name: "VHSCoreTests", dependencies: ["VHSCore"]),
    .testTarget(name: "VHSRendererTests", dependencies: ["VHSCore", "VHSRenderer"])
])
