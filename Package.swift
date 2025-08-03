// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftyXrayKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SwiftyXrayKit",
            targets: ["SwiftyXrayKit"]
        ),
    ],
    dependencies: [
      .package(url: "https://github.com/dima-u/SwiftyXrayCore", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "SwiftyXrayKit",
            dependencies: [
                .product(name: "SwiftyXrayCore", package: "SwiftyXrayCore")
            ],
            path: "Sources/SwiftyXrayKit",
            linkerSettings: [
                .linkedLibrary("resolv")
            ]
        ),
        .testTarget(
            name: "SwiftyXrayKitTests",
            dependencies: ["SwiftyXrayKit"],
            path: "Tests/SwiftyXrayKitTests"
        ),
    ]
)
