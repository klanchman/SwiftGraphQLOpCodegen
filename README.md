# SwiftGraphQLOpCodegen

SwiftGraphQLOpCodegen is a command line tool to generate Swift code from GraphQL operations.

It's geared toward situations where you have GraphQL queries and mutations you'd like to use in Swift,
but you _don't_ want to use auto-generated code to handle responses.

## Installation

You can install untrack using [Mint](https://github.com/yonaskolb/Mint):

```
mint install klanchman/SwiftGraphQLOpCodegen
```

Alternatively, you can clone/download the repository and build it from source manually:

```
swift package resolve
swift build -c release
```

## Usage

Provide the `--output` option the path to the Swift file you want to create,
plus a list of GraphQL files that contain the operations you want to generate
code from and any supporting types those files reference, like fragments.

### Example

If you wanted to generate code for the operations in the Example folder in this repo,
and save the output to `Example/Generated/Operations.swift`, you could run this command:

```
swift-graphql-op-codegen --output Example/Generated Example/GraphQL/**/*.graphql
```

## See Also

- [syrup](https://github.com/Shopify/syrup), a similar kind of code generator that also handles responses and can generate Kotlin and TypeScript code
- [Apollo iOS](https://github.com/apollographql/apollo-ios), a good all-around library that handles requests and responses, along with more advanced features like caching
- [SwiftGraphQL](https://github.com/maticzav/swift-graphql), a library that lets you write your operations in Swift
