// swift-tools-version:6.2.1
import PackageDescription

let package = Package(
    name: "AttestService",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework
        // https://github.com/vapor/vapor
        .package(url: "https://github.com/vapor/vapor.git", from: "4.121.0"),
        
        // 🔵 Non-blocking, event-driven networking for Swift. Used for custom executors
        // https://github.com/apple/swift-nio
            .package(url: "https://github.com/apple/swift-nio.git", from: "2.92.1"),
        
        // AppAttest
        .package(url: "https://github.com/topscrech/Attester.git", branch: "main")
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
    ]
)

fileprivate let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny")
]
