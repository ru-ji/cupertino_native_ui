// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "cupertino_widgets",
    // The floor an app can LINK this package at, not the one it needs to get
    // anything out of it. Every view here is iOS 26 (Liquid Glass) and is
    // annotated as such; below 26 the plugin registers nothing and the app
    // still builds and runs. Declaring 26 here would instead force every
    // consuming app to raise its own deployment target to 26 just to compile.
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "cupertino-widgets", targets: ["cupertino_widgets"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "cupertino_widgets",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: []
        )
    ]
)
