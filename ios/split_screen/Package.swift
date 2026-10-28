// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "split_screen",
    platforms: [.iOS("15.0")],
    products: [.library(name: "split-screen", targets: ["split_screen"])],
    dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
    targets: [
        .target(name: "split_screen", dependencies: [
            .product(name: "FlutterFramework", package: "FlutterFramework")
        ]),
        .testTarget(name: "split_screenTests", dependencies: ["split_screen"])
    ]
)
