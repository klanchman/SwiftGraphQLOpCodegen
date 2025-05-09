// swift-tools-version:6.1

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
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/GraphQLSwift/GraphQL.git", from: "3.0.2"),
        .package(url: "https://github.com/stencilproject/Stencil.git", exact: "0.15.1"),
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
                "Stencil",
            ],
            resources: [
                .copy("Resources/Templates")
            ]
        ),
        .testTarget(
            name: "SwiftGraphQLOpCodegenTests",
            dependencies: ["SwiftGraphQLOpCodegen"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
