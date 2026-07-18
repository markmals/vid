import Foundation
import Testing

@testable import MediaConversion

@Suite("Conversion subtitle discovery")
struct ConversionSubtitleTests {
    @Test("Matching supported sidecars are discovered recursively by basename qualifiers")
    func matchingTextSidecars() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let video = try writeTestFile(directory.appendingPathComponent("movie.mkv"))
        for filename in [
            "movie.srt",
            "movie.en.forced.vtt",
            "movie.sdh.txt",
            "movie.jp.ttxt",
            "movie.commentary.sub",
            "movie.ass",
            "other.forced.srt",
        ] {
            try writeTestFile(directory.appendingPathComponent(filename))
        }

        let subtitles = try ExternalSubtitleDiscovery().subtitles(matching: video)

        #expect(
            subtitles.map { $0.url.lastPathComponent } == [
                "movie.commentary.sub",
                "movie.en.forced.vtt",
                "movie.jp.ttxt",
                "movie.sdh.txt",
                "movie.srt",
            ])
        #expect(
            subtitles.first { $0.url.lastPathComponent == "movie.en.forced.vtt" }
                == ExternalSubtitle(
                    url: directory.appendingPathComponent("movie.en.forced.vtt"),
                    language: "en",
                    role: .forced
                ))
        #expect(
            subtitles.first { $0.url.lastPathComponent == "movie.sdh.txt" }?.role == .sdh)
        #expect(
            subtitles.first { $0.url.lastPathComponent == "movie.jp.ttxt" }?.language == "jp")
        #expect(
            subtitles.first { $0.url.lastPathComponent == "movie.srt" }?.role == .unspecified)
    }

    @Test("Forced, default, and SDH filename markers receive preference roles")
    func filenameRoles() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let video = try writeTestFile(directory.appendingPathComponent("feature.mov"))
        for filename in [
            "feature.forced.srt",
            "feature.default.srt",
            "feature.cc.srt",
            "feature.hi.srt",
        ] {
            try writeTestFile(directory.appendingPathComponent(filename))
        }

        let subtitles = try ExternalSubtitleDiscovery().subtitles(matching: video)
        let roles = Dictionary(
            uniqueKeysWithValues: subtitles.map { ($0.url.lastPathComponent, $0.role) })

        #expect(roles["feature.forced.srt"] == .forced)
        #expect(roles["feature.default.srt"] == .defaultTrack)
        #expect(roles["feature.cc.srt"] == .sdh)
        #expect(roles["feature.hi.srt"] == .sdh)
    }
}
