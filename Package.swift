// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "SwiftGraphQLOpCodegen",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "swift-graphql-op-codegen", targets: ["swift-graphql-op-codegen"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.3"),
        .package(url: "https://github.com/GraphQLSwift/GraphQL.git", from: "2.2.1"),
    ],
    targets: [
        .executableTarget(
            name: "swift-graphql-op-codegen",
            dependencies: ["SwiftGraphQLOpCodegen"]
        ),
        .target(
            name: "SwiftGraphQLOpCodegen",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "GraphQL", package: "GraphQL"),
            ]
        ),
        .testTarget(
            name: "SwiftGraphQLOpCodegenTests",
            dependencies: ["SwiftGraphQLOpCodegen"]
        ),
    ]
)
