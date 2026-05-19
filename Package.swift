// swift-tools-version:6.3.2
import PackageDescription

let package = Package(
    name: "AttestService",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // HTTP framework
        // https://github.com/vapor/vapor
        .package(url: "https://github.com/vapor/vapor", from: "4.121.4"),
        
        // Networking
        // https://github.com/apple/swift-nio
            .package(url: "https://github.com/apple/swift-nio", from: "2.99.0"),
        
        // AppAttest
        // https://github.com/topscrech/Attester
            .package(url: "https://github.com/topscrech/Attester", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "AttestService",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "Attester", package: "Attester")
            ],
            swiftSettings: swiftSettings
            //        ),
            //        .testTarget(
            //            name: "AttestServiceTests",
            //            dependencies: [
            //                .target(name: "AttestService"),
            //                .product(name: "VaporTesting", package: "vapor")
            //            ],
            //            swiftSettings: swiftSettings
        )
    ],
    swiftLanguageModes: [.v6]
)

fileprivate let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny")
]
