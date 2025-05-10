# SwiftGraphQLOpCodegen

SwiftGraphQLOpCodegen is a command line tool to generate Swift code from GraphQL operations.

It's geared toward situations where you have GraphQL queries and mutations you'd like to use in Swift,
but you _don't_ want to use auto-generated code to handle responses.

## Installation

You can install untrack using [Mint](https://github.com/yonaskolb/Mint):

```
mint install klanchman/SwiftGraphQLOpCodegen
```

You can also install it using [mise](https://github.com/jdx/mise):

```
mise install "spm:klanchman/SwiftGraphQLOpCodegen"
```

Alternatively, you can clone/download the repository and build it from source manually:

```
swift package resolve
swift build -c release
```

## Usage

Run `swift-graphql-op-codegen --help` for usage information.

## Templates

There are 3 templates available to customize, described below.
Templates are written using [Stencil](https://github.com/stencilproject/Stencil).
The context available to them is described below using Swift types.

### AllOperations.stencil

Used in single-file mode. This template contains shared types used by operations
and the operations themselves.

#### Context

```swift
struct Context {
  let operations: [Operation]

  struct Operation {
    /// The name of the operation.
    name: String
    /// The GraphQL source of the operation including necessary fragments, in a minified format.
    mergedSource: String
    /// Input variable definitions.
    variables: [Variable]

    struct Variable {
      /// The name of the variable.
      let name: String

      /// A Swift type equivalent to the GraphQL type of the variable.
      ///
      /// GraphQL optionals are rendered as "double optionals" in Swift. For example,
      /// a GraphQL `String` is rendered as `String??` in Swift. This allows you to
      /// pass 3 kinds of values: a String, nil/undefined, and null (`.some(nil)` in Swift),
      /// since some GraphQL APIs distinguish between undefined and null.
      let swiftType: String
    }
  }
}
```

### GraphQLOperation.stencil

Used in multi-file mode. This template contains shared types used by operations.
The default template defines a protocol for operations to conform to,
and an empty enum to use as a namespace for your operations.

#### Context

None

### Operation.stencil

Used in multi-file mode. This template defines how individual operations are generated.

#### Context

```swift
struct Context {
  let operation: Operation

  struct Operation {
    /// The name of the operation.
    name: String
    /// The GraphQL source of the operation including necessary fragments, in a minified format.
    mergedSource: String
    /// Input variable definitions.
    variables: [Variable]

    struct Variable {
      /// The name of the variable.
      let name: String

      /// A Swift type equivalent to the GraphQL type of the variable.
      ///
      /// GraphQL optionals are rendered as "double optionals" in Swift. For example,
      /// a GraphQL `String` is rendered as `String??` in Swift. This allows you to
      /// pass 3 kinds of values: a String, nil/undefined, and null (`.some(nil)` in Swift),
      /// since some GraphQL APIs distinguish between undefined and null.
      let swiftType: String
    }
  }
}
```

## See Also

- [syrup](https://github.com/Shopify/syrup), a similar kind of code generator that also handles responses and can generate Kotlin and TypeScript code
- [Apollo iOS](https://github.com/apollographql/apollo-ios), a good all-around library that handles requests and responses, along with more advanced features like caching
- [SwiftGraphQL](https://github.com/maticzav/swift-graphql), a library that lets you write your operations in Swift
