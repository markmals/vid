import ArgumentParser
import Foundation
import Testing

@testable import MediaDiscovery
@testable import MediaProcessing
@testable import vid

@Suite("Command options")
struct CommandOptionsTests {
    @Test("Input options require paths and discover parsed inputs")
    func inputOptions() throws {
        let empty = try MediaInputOptions.parse([])
        #expect(throws: ValidationError.self) {
            try empty.files()
        }

        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = try writeTestFile(directory.appendingPathComponent("movie.mkv"))
        let options = try MediaInputOptions.parse([input.path, "--recursive"])

        #expect(options.includesSubdirectories)
        #expect(try options.files() == [input.standardizedFileURL])
    }

    @Test("Output options map every policy value and reject conflicts")
    func outputOptions() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let options = try MediaOutputOptions.parse([
            "--output-directory", directory.path,
            "--remove-source",
            "--overwrite",
        ])
        let policy = try options.makeOutputPolicy()

        #expect(policy.outputDirectory == directory.standardizedFileURL)
        #expect(policy.shouldRemoveSource)
        #expect(policy.shouldOverwriteExistingOutput)
        #expect(!policy.shouldReplaceInput)

        let conflicting = try MediaOutputOptions.parse([
            "--replace", "--output-directory", directory.path,
        ])
        #expect(throws: ValidationError.self) {
            try conflicting.makeOutputPolicy()
        }

        let replacement = try MediaOutputOptions.parse(["--replace"])
        #expect(try replacement.makeOutputPolicy().shouldReplaceInput)
    }

    @Test("CLI codec values map to domain settings")
    func enumMappings() {
        switch AudioCodecArgument.aac.encoding(bitrate: "192k") {
        case .aac(let bitrate): #expect(bitrate == "192k")
        default: Issue.record("AAC did not map to AAC encoding")
        }
        switch AudioCodecArgument.copy.encoding(bitrate: "ignored") {
        case .copy: break
        default: Issue.record("Copy did not map to copy encoding")
        }
        switch AudioCodecArgument.eac3.encoding(bitrate: "640k") {
        case .eac3(let bitrate): #expect(bitrate == "640k")
        default: Issue.record("E-AC-3 did not map to E-AC-3 encoding")
        }

        switch SubtitleHandlingArgument.extract.handling {
        case .extractBitmap: break
        default: Issue.record("Extract did not map to bitmap extraction")
        }
        switch SubtitleHandlingArgument.none.handling {
        case .none: break
        default: Issue.record("None did not map to dropping subtitles")
        }
        switch SubtitleHandlingArgument.text.handling {
        case .textOnly: break
        default: Issue.record("Text did not map to text-only subtitles")
        }
    }
}
