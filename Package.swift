// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "LittleRadio", platforms: [.macOS(.v14)], products: [.executable(name: "LittleRadio", targets: ["LittleRadio"])], targets: [.target(name: "CZstd", path: "Vendor/Zstd", sources: ["zstddeclib.c"], publicHeadersPath: "include"), .executableTarget(name: "LittleRadio", dependencies: ["CZstd"], path: "Sources")])
