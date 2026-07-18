import ArgumentParser
import Foundation
import Testing

@testable import vid

@Suite("Commands", .serialized)
struct CommandTests {
    @Test("Every media command parses options and completes its workflow")
    func successfulCommands() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let tools = try installFakeMediaTools(in: directory)
        let outputDirectory = directory.appendingPathComponent("outputs")
        try FileManager.default.createDirectory(
            at: outputDirectory, withIntermediateDirectories: true)

        try await withPrependedPath(tools) {
            let remuxInput = try writeTestFile(directory.appendingPathComponent("remux.mkv"))
            var remux = try RemuxCommand.parse([
                remuxInput.path,
                "--subtitles", "none",
                "--apple-compatible",
                "--audio-codec", "aac",
                "--audio-bitrate", "192k",
                "--remove-source",
            ])
            try await remux.run()
            #expect(!FileManager.default.fileExists(atPath: remuxInput.path))
            #expect(
                FileManager.default.fileExists(
                    atPath: directory.appendingPathComponent("remux.mp4").path
                ))

            let tagInput = try writeTestFile(directory.appendingPathComponent("tag.mkv"))
            var tag = try TagCommand.parse([
                tagInput.path,
                "--subtitles", "extract",
                "--audio-codec", "copy",
                "--audio-bitrate", "320k",
                "--output-directory", outputDirectory.path,
            ])
            try await tag.run()
            #expect(
                FileManager.default.fileExists(
                    atPath: outputDirectory.appendingPathComponent("tag.mp4").path
                ))
            #expect(
                FileManager.default.fileExists(
                    atPath: outputDirectory.appendingPathComponent("tag_sub3.sup").path
                ))

            let encodeInput = try writeTestFile(directory.appendingPathComponent("encode.mkv"))
            var encode = try EncodeCommand.parse([
                encodeInput.path,
                "--subtitles", "text",
                "--audio-codec", "eac3",
                "--audio-bitrate", "640k",
                "--crf", "30",
                "--preset", "slow",
                "--exclude-audio-language", "FRA",
                "--normalize-dispositions",
            ])
            try await encode.run()
            #expect(
                FileManager.default.fileExists(
                    atPath: directory.appendingPathComponent("encode.mp4").path
                ))

            let skippedInput = try writeTestFile(directory.appendingPathComponent("skipped.mkv"))
            var skipped = try EncodeCommand.parse([skippedInput.path, "--skip-hevc"])
            try await skipped.run()
            #expect(
                !FileManager.default.fileExists(
                    atPath: directory.appendingPathComponent("skipped.mp4").path
                ))

            let repairInput = try writeTestFile(directory.appendingPathComponent("repair.mkv"))
            var repair = try RepairCommand.parse([repairInput.path])
            try await repair.run()
            #expect(
                FileManager.default.fileExists(
                    atPath: directory.appendingPathComponent("repair.mp4").path
                ))

            let subtitleVideo = try writeTestFile(directory.appendingPathComponent("single.mkv"))
            let subtitle = try writeTestFile(directory.appendingPathComponent("single.srt"))
            var add = try AddSubtitleCommand.parse([
                subtitleVideo.path,
                subtitle.path,
                "--language", "fra",
                "--title", "French",
                "--remove-subtitle",
            ])
            try await add.run()
            #expect(!FileManager.default.fileExists(atPath: subtitle.path))
            #expect(
                FileManager.default.fileExists(
                    atPath: directory.appendingPathComponent("single.mp4").path
                ))

            let matchingVideo = try writeTestFile(directory.appendingPathComponent("matching.mkv"))
            let matchingSubtitle = try writeTestFile(
                directory.appendingPathComponent("matching.vtt"))
            var matching = try AddMatchingSubtitlesCommand.parse([
                matchingVideo.path,
                "--subtitle-extension", ".vtt",
                "--language", "spa",
                "--title", "Spanish",
                "--remove-subtitles",
            ])
            try await matching.run()
            #expect(!FileManager.default.fileExists(atPath: matchingSubtitle.path))
            #expect(
                FileManager.default.fileExists(
                    atPath: directory.appendingPathComponent("matching.mp4").path
                ))
        }
    }

    @Test("Encode validation accepts boundaries and rejects out-of-range CRF")
    func encodeValidation() throws {
        var minimum = try EncodeCommand.parse(["movie.mkv", "--crf", "0"])
        try minimum.validate()
        var maximum = try EncodeCommand.parse(["movie.mkv", "--crf", "51"])
        try maximum.validate()

        var belowMinimum = minimum
        belowMinimum.crf = -1
        #expect(throws: ValidationError.self) {
            try belowMinimum.validate()
        }
        var aboveMaximum = maximum
        aboveMaximum.crf = 52
        #expect(throws: ValidationError.self) {
            try aboveMaximum.validate()
        }
    }

    @Test("Subtitle commands validate files and extension")
    func subtitleValidation() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let video = try writeTestFile(directory.appendingPathComponent("movie.mkv"))
        let subtitle = try writeTestFile(directory.appendingPathComponent("movie.srt"))

        var missingVideo = try AddSubtitleCommand.parse([
            directory.appendingPathComponent("missing.mkv").path,
            subtitle.path,
        ])
        await #expect(throws: VidError.self) {
            try await missingVideo.run()
        }

        var missingSubtitle = try AddSubtitleCommand.parse([
            video.path,
            directory.appendingPathComponent("missing.srt").path,
        ])
        await #expect(throws: VidError.self) {
            try await missingSubtitle.run()
        }

        var sameFile = try AddSubtitleCommand.parse([video.path, video.path])
        await #expect(throws: ValidationError.self) {
            try await sameFile.run()
        }

        var emptyExtension = try AddMatchingSubtitlesCommand.parse([
            video.path,
            "--subtitle-extension", "...",
        ])
        await #expect(throws: ValidationError.self) {
            try await emptyExtension.run()
        }
    }
}
