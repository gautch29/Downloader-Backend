// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "backend",
    platforms: [
       .macOS(.v13)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        // 🗄 An ORM for SQL and NoSQL databases.
        .package(url: "https://github.com/vapor/fluent.git", from: "4.8.0"),
        // SQLite driver for Fluent
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
        // 🥣 HTML parsing
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
        // 🔑 JWT
        .package(url: "https://github.com/vapor/jwt.git", from: "4.0.0"),
        // 🔒 BCrypt
        .package(url: "https://github.com/vapor/bcrypt.git", from: "1.0.0"),
        // 🚀 Async HTTP Client
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.19.0"),
    ],
    targets: [
        .executableTarget(
            name: "Run",
            dependencies: [
                .target(name: "App")
            ]
        ),
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "BCrypt", package: "bcrypt"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite this being
                // the default behavior on Swift 5.10+, we specify it explicitly to ensure consistent
                // behavior across toolchains.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),

    ]
)
