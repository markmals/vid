import Foundation
import Testing

@testable import MediaDiscovery
@testable import MediaProcessing

@Suite("Filesystem behavior")
struct FilesystemTests {
    @Test("Path resolution handles absolute, relative, and home paths")
    func pathResolution() {
        let absolute = FilePathResolver.resolvedURL(for: "/tmp/../tmp/movie.mkv")
        #expect(absolute.path == "/tmp/movie.mkv")

        let relative = FilePathResolver.resolvedURL(for: "Sources/../Package.swift")
        #expect(
            relative.path
                == URL(
                    fileURLWithPath: FileManager.default.currentDirectoryPath
                ).appendingPathComponent("Package.swift").standardizedFileURL.path)

        let home = FilePathResolver.resolvedURL(for: "~/movie.mkv")
        #expect(
            home.path
                == FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("movie.mkv").path)
    }

    @Test("Input discovery accepts files, removes duplicates, and reports empty inputs")
    func inputDiscoveryEdges() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let media = try writeTestFile(directory.appendingPathComponent("MOVIE.MKV"))
        try writeTestFile(directory.appendingPathComponent(".hidden.mp4"))
        try writeTestFile(directory.appendingPathComponent("notes.txt"))

        let discovered = try InputDiscovery().mediaFiles(
            at: [media.path, media.path, directory.path],
            recursive: false,
        )
        #expect(discovered == [media.standardizedFileURL])

        #expect(throws: MediaDiscoveryError.self) {
            try InputDiscovery().mediaFiles(
                at: [directory.appendingPathComponent("missing").path],
                recursive: false,
            )
        }

        let emptyDirectory = directory.appendingPathComponent("empty")
        try FileManager.default.createDirectory(
            at: emptyDirectory, withIntermediateDirectories: true)
        #expect(throws: MediaDiscoveryError.self) {
            try InputDiscovery().mediaFiles(at: [emptyDirectory.path], recursive: true)
        }
    }

    @Test("Output transactions validate destinations and collision policy")
    func outputResolution() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try writeTestFile(
            directory.appendingPathComponent("movie.mkv"), contents: "source")
        let missingDirectory = directory.appendingPathComponent("missing")

        #expect(throws: MediaProcessingError.self) {
            try OutputTransaction(
                sourceURL: source,
                outputFilenameSuffix: "remuxed",
                policy: outputPolicy(directory: missingDirectory),
            )
        }

        let regularFile = try writeTestFile(directory.appendingPathComponent("not-a-directory"))
        #expect(throws: MediaProcessingError.self) {
            try OutputTransaction(
                sourceURL: source,
                outputFilenameSuffix: "remuxed",
                policy: outputPolicy(directory: regularFile),
            )
        }

        #expect(throws: MediaProcessingError.self) {
            try OutputTransaction(
                sourceURL: source,
                outputFilenameSuffix: "remuxed",
                policy: outputPolicy(directory: directory, replaceInput: true),
            )
        }

        let existingOutput = try writeTestFile(
            directory.appendingPathComponent("movie.mp4"),
            contents: "old",
        )
        #expect(throws: MediaProcessingError.self) {
            try OutputTransaction(
                sourceURL: source,
                outputFilenameSuffix: "remuxed",
                policy: outputPolicy(),
            )
        }

        let overwrite = try OutputTransaction(
            sourceURL: source,
            outputFilenameSuffix: "remuxed",
            policy: outputPolicy(overwrite: true),
        )
        try writeTestFile(overwrite.temporaryURL, contents: "new")
        try overwrite.commit()
        #expect(try String(contentsOf: existingOutput, encoding: .utf8) == "new")
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test("Replacement and discard preserve transaction invariants")
    func replacementAndDiscard() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try writeTestFile(
            directory.appendingPathComponent("movie.mp4"), contents: "source")

        let replacement = try OutputTransaction(
            sourceURL: source,
            outputFilenameSuffix: "unused",
            policy: outputPolicy(replaceInput: true),
        )
        #expect(replacement.finalURL == source.standardizedFileURL)
        try writeTestFile(replacement.temporaryURL, contents: "replacement")
        try replacement.commit()
        #expect(try String(contentsOf: source, encoding: .utf8) == "replacement")

        let discarded = try OutputTransaction(
            sourceURL: source,
            outputFilenameSuffix: "discarded",
            policy: outputPolicy(),
        )
        try writeTestFile(discarded.temporaryURL)
        discarded.discardTemporaryOutput()
        #expect(!FileManager.default.fileExists(atPath: discarded.temporaryURL.path))
        discarded.discardTemporaryOutput()
    }
}
