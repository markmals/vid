# Contributor Guidelines

Be sure to read all the documents in `./.agents/rules/*.md` before beginning a session.

## Project Brief

This is a Swift port of the media script `./Resources/media-commands.sh`.

The goal of this project is readable and well-organized code, share as many implementations as possible, make the code as composable as possible, and to produce a small binary with low memory consumption that runs on both macOS and Ubuntu, with an eye towards support on other Linux platforms and maybe even Windows.

## Swift Packages

This project uses a pure Swift Package workflow with no Xcode or Xcode toolchains. Whenever possible the Swift Standard library or 1st party Swift packages should be preferred to Foundation or any 3rd party libraries or frameworks.

## Tooling

- Install toolchain: `mise install`
- Build: `mise run build`
- Build for release: `mise run build:release`
- Build one release target: `mise run build:release:<platform>:<architecture>`
- Build universal macOS release: `mise run build:release:macos`
- Build static Linux releases: `mise run build:release:linux`
- Build every release target: `mise run build:all`
- Run: `mise run run -- <arguments>`
- Format: `mise run format`
- Lint: `mise run lint`
- Test: `mise run test`
