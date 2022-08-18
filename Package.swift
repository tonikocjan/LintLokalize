// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "LintLokalization",
  products: [
    .library(
      name: "LintLokalization",
      targets: ["LintLokalization"]),
    .executable(
      name: "Run",
      targets: ["Run"])
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
      name: "LintLokalization",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "Rainbow",
      ]),
    .executableTarget(
      name: "Run",
      dependencies: [
        "LintLokalization",
      ]
    ),
    .testTarget(
      name: "LintLokalizationTests",
      dependencies: ["LintLokalization"]),
  ]
)
