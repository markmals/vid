# Contributor Guidelines

Be sure to read all the documents in `./.agents/rules` before beginning a session.

## Project Brief

This is a Swift port of the media scripts found at `~/Developer/Scripts/media-commands.sh`.

The goal of this project is readable and well-organized code, share as many implementations as possible, make the code as composable as possible, and to produce a small binary with low memory consumption that runs on both macOS and Ubuntu, with an eye towards support on other Linux platforms and maybe even Windows.

## Swift Packages

This project uses a pure Swift Package workflow with no Xcode or Xcode toolchains. Whenever possible we use the Swift Standard library of official Swift packages instead of Foundation. Some examples:

- [Swift Argument Parser](https://github.com/apple/swift-argument-parser)
- [Swift Subprocess](https://github.com/swiftlang/swift-subprocess)
- [Swift System](https://github.com/apple/swift-system)
- [Swift Log](https://github.com/apple/swift-log)
- [Swift Collections](https://github.com/apple/swift-collections)
- [Swift Numerics](https://github.com/apple/swift-numerics)
- [Swift Algorithms](https://github.com/apple/swift-algorithms)
- [Swift Async Algorithms](https://github.com/apple/swift-async-algorithms)
- [Swift Configuration](https://github.com/apple/swift-configuration)
- [Swift Markdown](https://github.com/swiftlang/swift-markdown)
- [Swift HTTP API](https://github.com/apple/swift-http-api-proposal)
- [Swift HTTP Types](https://github.com/apple/swift-http-types)
- [Swift HTTP Server](https://github.com/swift-server/swift-http-server)
- [Swift Async HTTP Client](https://github.com/swift-server/async-http-client)
- [Swift Testing](https://github.com/swiftlang/swift-testing)

Not all of these libraries need to be used if they are not necessary for the functionality that we're building, but they should be preferred to Foundation or any 3rd party libraries or frameworks if they are necessary.

## Tooling

- Install toolchain: `mise install`
- Build: `mise run build`
- Build for release: `mise run build:release`
- Run: `mise run run -- <arguments>`
- Format: `mise run format`
- Lint: `mise run lint`
- Test: `mise run test`
