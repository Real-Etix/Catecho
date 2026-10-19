// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "LittleRadio", platforms: [.macOS(.v14)], products: [.executable(name: "LittleRadio", targets: ["LittleRadio"])], targets: [.executableTarget(name: "LittleRadio", path: "Sources")])
