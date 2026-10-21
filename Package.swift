// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "HakuMac", platforms: [.macOS(.v14)],
  products: [
    .executable(name: "HakuMac", targets: ["HakuMac"]),
    .executable(name: "haku-mac-probe", targets: ["HakuMacProbe"]),
    .library(name: "HakuCore", targets: ["HakuCore"]),
  ],
  targets: [
    .target(name: "HakuCore"),
    .executableTarget(
      name: "HakuMac", dependencies: ["HakuCore"], resources: [.process("Resources")]),
    .executableTarget(name: "HakuMacProbe", dependencies: ["HakuCore"]),
    .testTarget(name: "HakuCoreTests", dependencies: ["HakuCore"]),
  ]
)
