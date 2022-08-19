// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "LintLokalization",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "Lib",
      targets: ["Lib"]),
    .executable(
      name: "LintLokalize",
      targets: ["LintLokalize"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-argument-parser",
      .upToNextMajor(from: "1.0.0")),
    .package(
      url: "https://github.com/onevcat/Rainbow.git",
      from: "4.0.1"),
  ],
  targets: [
    .target(
      name: "Lib",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "Rainbow",
      ]),
    .executableTarget(
      name: "LintLokalize",
      dependencies: [
        "Lib",
      ]
    ),
    .testTarget(
      name: "LintLokalizationTests",
      dependencies: ["Lib"]),
  ]
)
