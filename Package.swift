// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "GameEngineLib",
  platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17)],
  products: [.library(name: "GameEngineLib", targets: ["GameEngineLib"])],
  targets: [
    .target(name: "GameEngineLib"),
    .testTarget(name: "GameEngineLibTests", dependencies: ["GameEngineLib"]),
  ]
)
