import Foundation
import Testing

@testable import MediaDiscovery
@testable import MediaProcessing
@testable import MediaSubtitles

@Suite("File workflows")
struct FileWorkflowTests {
    @Test("Directory discovery is deterministic and recursion is explicit")
    func inputDiscovery() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let nestedDirectory = directory.appendingPathComponent("nested")
        try FileManager.default.createDirectory(
            at: nestedDirectory, withIntermediateDirectories: true)
        try Data().write(to: directory.appendingPathComponent("direct.mp4"))
        try Data().write(to: directory.appendingPathComponent("notes.txt"))
        try Data().write(to: nestedDirectory.appendingPathComponent("nested.mkv"))

        let directFiles = try InputDiscovery().mediaFiles(at: [directory.path], recursive: false)
        let recursiveFiles = try InputDiscovery().mediaFiles(at: [directory.path], recursive: true)

        #expect(directFiles.map(\.lastPathComponent) == ["direct.mp4"])
        #expect(recursiveFiles.map(\.lastPathComponent) == ["direct.mp4", "nested.mkv"])
    }

    @Test("A completed output is committed before its source is removed")
    func outputCommitRemovesSource() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("movie.mkv")
        try Data("source".utf8).write(to: source)
        let transaction = try OutputTransaction(
            sourceURL: source,
            outputFilenameSuffix: "remuxed",
            policy: OutputPolicy(
                outputDirectory: nil,
                shouldOverwriteExistingOutput: false,
                shouldRemoveSource: true,
                shouldReplaceInput: false,
            ),
        )
        try Data("output".utf8).write(to: transaction.temporaryURL)

        try transaction.commit()

        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(FileManager.default.fileExists(atPath: transaction.finalURL.path))
    }

    @Test("An empty output never removes its source")
    func emptyOutputPreservesSource() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("movie.mkv")
        try Data("source".utf8).write(to: source)
        let transaction = try OutputTransaction(
            sourceURL: source,
            outputFilenameSuffix: "remuxed",
            policy: OutputPolicy(
                outputDirectory: nil,
                shouldOverwriteExistingOutput: false,
                shouldRemoveSource: true,
                shouldReplaceInput: false,
            ),
        )
        try Data().write(to: transaction.temporaryURL)

        #expect(throws: MediaProcessingError.self) {
            try transaction.commit()
        }
        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(!FileManager.default.fileExists(atPath: transaction.finalURL.path))
    }

    @Test("Adding subtitles to an MP4 uses the unambiguous collision suffix")
    func subtitleOutputFilename() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("movie.mp4")
        try Data("source".utf8).write(to: source)
        let plan = AddSubtitlePlan(
            subtitle: directory.appendingPathComponent("movie.srt"),
            language: "eng",
            title: "ENG",
        )
        let transaction = try OutputTransaction(
            sourceURL: source,
            outputFilenameSuffix: plan.outputFilenameSuffix,
            policy: OutputPolicy(
                outputDirectory: nil,
                shouldOverwriteExistingOutput: false,
                shouldRemoveSource: false,
                shouldReplaceInput: false,
            ),
        )

        #expect(transaction.finalURL.lastPathComponent == "movie.subtitled.mp4")
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vid-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
