import ArgumentParser
import Foundation
import Testing

@testable import vid

@Suite("Media converter", .serialized)
struct MediaConverterTests {
    @Test(
        "A directory conversion recurses, filters supported files, replaces sources, and reports progress"
    )
    func recursiveBatchConversion() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = directory.appendingPathComponent("library")
        let nested = library.appendingPathComponent("season")
        let intermediates = directory.appendingPathComponent("intermediates")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: intermediates, withIntermediateDirectories: true)

        let avi = try writeTestFile(library.appendingPathComponent("alpha.avi"), contents: "avi")
        let mov = try writeTestFile(nested.appendingPathComponent("beta.mov"), contents: "mov")
        let mp4 = try writeTestFile(library.appendingPathComponent("gamma.mp4"), contents: "mp4")
        let ignored = try writeTestFile(
            library.appendingPathComponent("ignored.webm"),
            contents: "ignored"
        )
        let tools = try makeConversionTools(in: directory, succeeds: true)
        let progress = ConversionProgressRecorder()
        let converter = MediaConverter(
            runner: ToolRunner(executablePaths: tools),
            temporaryDirectoryRoot: intermediates,
            reportProgress: { await progress.record($0) }
        )

        let outputs = try await converter.convert(path: library.path, videoCodec: .h265)

        #expect(
            outputs.map(\.lastPathComponent).sorted() == ["alpha.mp4", "beta.mp4", "gamma.mp4"])
        #expect(!FileManager.default.fileExists(atPath: avi.path))
        #expect(!FileManager.default.fileExists(atPath: mov.path))
        #expect(FileManager.default.fileExists(atPath: mp4.path))
        #expect(try String(contentsOf: mp4, encoding: .utf8) == "converted")
        #expect(try String(contentsOf: ignored, encoding: .utf8) == "ignored")
        #expect(try FileManager.default.contentsOfDirectory(atPath: intermediates.path).isEmpty)

        let events = await progress.recordedEvents()
        #expect(events.contains(.batch(processed: 0, total: 3)))
        #expect(events.contains(.batch(processed: 1, total: 3)))
        #expect(events.contains(.batch(processed: 2, total: 3)))
        #expect(events.contains(.batch(processed: 3, total: 3)))
        for input in [avi, mov, mp4] {
            #expect(events.contains(.file(input.standardizedFileURL, fraction: 0)))
            #expect(events.contains(.file(input.standardizedFileURL, fraction: 0.5)))
            #expect(events.contains(.file(input.standardizedFileURL, fraction: 1)))
        }
    }

    @Test("A failed conversion preserves an MP4 source and removes intermediate artifacts")
    func failedConversionPreservesSource() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let intermediates = directory.appendingPathComponent("intermediates")
        try FileManager.default.createDirectory(
            at: intermediates, withIntermediateDirectories: true)
        let input = try writeTestFile(
            directory.appendingPathComponent("movie.mp4"),
            contents: "original"
        )
        let tools = try makeConversionTools(in: directory, succeeds: false)
        let converter = MediaConverter(
            runner: ToolRunner(executablePaths: tools),
            temporaryDirectoryRoot: intermediates
        )

        await #expect(throws: VidError.self) {
            try await converter.convert(path: input.path, videoCodec: .h265)
        }

        #expect(try String(contentsOf: input, encoding: .utf8) == "original")
        #expect(try FileManager.default.contentsOfDirectory(atPath: intermediates.path).isEmpty)
    }

    @Test("Extra text subtitles become SRT sidecars and bitmap subtitles are extracted")
    func subtitleSidecars() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let intermediates = directory.appendingPathComponent("intermediates")
        try FileManager.default.createDirectory(
            at: intermediates, withIntermediateDirectories: true)
        let input = try writeTestFile(directory.appendingPathComponent("movie.mkv"))
        try writeTestFile(directory.appendingPathComponent("movie.forced.srt"))
        try writeTestFile(directory.appendingPathComponent("movie.jp.vtt"))
        try writeTestFile(directory.appendingPathComponent("movie.sdh.txt"))
        let tools = try makeConversionTools(
            in: directory,
            succeeds: true,
            probeJSON: subtitleProbeJSON
        )
        let converter = MediaConverter(
            runner: ToolRunner(executablePaths: tools),
            temporaryDirectoryRoot: intermediates
        )

        let outputs = try await converter.convert(path: input.path, videoCodec: .h265)

        #expect(outputs.map(\.lastPathComponent) == ["movie.mp4"])
        #expect(!FileManager.default.fileExists(atPath: input.path))
        for filename in [
            "movie.eng.default.srt",
            "movie.eng.sdh.srt",
            "movie.jp.srt",
            "movie.sdh.srt",
            "movie.eng.pgssub.sup",
        ] {
            let sidecar = directory.appendingPathComponent(filename)
            #expect(FileManager.default.fileExists(atPath: sidecar.path))
            #expect(try String(contentsOf: sidecar, encoding: .utf8) == "converted")
        }
        #expect(
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("movie.forced.srt").path
            ))
        #expect(try FileManager.default.contentsOfDirectory(atPath: intermediates.path).isEmpty)
    }

    @Test("The convert command exposes codec selection through the root CLI")
    func commandParsing() throws {
        let defaultCommand = try ConvertCommand.parse(["movie.mkv"])
        #expect(defaultCommand.videoCodec == .h265)

        let h264Command = try ConvertCommand.parse(["movie.mkv", "--video-codec", "h264"])
        #expect(h264Command.videoCodec == .h264)

        let rootCommand = try Vid.parseAsRoot(["convert", "movie.mkv", "--video-codec", "h265"])
        #expect(rootCommand is ConvertCommand)
    }

    private var subtitleProbeJSON: String {
        """
        {"streams":[
          {"index":0,"codec_name":"hevc","codec_tag_string":"hvc1","codec_type":"video","disposition":{"attached_pic":0}},
          {"index":1,"codec_name":"aac","codec_type":"audio","channels":2},
          {"index":2,"codec_name":"subrip","codec_type":"subtitle","disposition":{"default":1},"tags":{"language":"eng"}},
          {"index":3,"codec_name":"webvtt","codec_type":"subtitle","disposition":{"hearing_impaired":1},"tags":{"language":"eng","title":"English SDH"}},
          {"index":4,"codec_name":"hdmv_pgs_subtitle","codec_type":"subtitle","tags":{"language":"eng"}}
        ],"format":{"duration":"10.0"}}
        """
    }

    private func makeConversionTools(
        in directory: URL,
        succeeds: Bool,
        probeJSON: String? = nil,
    ) throws -> [String: String] {
        let tools = directory.appendingPathComponent("tools-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        let ffprobe = try makeExecutable(
            in: tools,
            name: "ffprobe",
            script: "printf '%s\\n' '\(probeJSON ?? defaultProbeJSON)'"
        )
        let ffmpegScript =
            succeeds
            ? """
            output=''
            for argument do
                output="$argument"
            done
            printf '%s\\n' 'out_time_us=5000000' 'progress=continue'
            printf 'converted' > "$output"
            printf '%s\\n' 'out_time_us=10000000' 'progress=end'
            """
            : """
            printf '%s\\n' 'out_time_us=5000000' 'progress=continue'
            exit 17
            """
        let ffmpeg = try makeExecutable(
            in: tools,
            name: "ffmpeg",
            script: ffmpegScript
        )
        return ["ffprobe": ffprobe.path, "ffmpeg": ffmpeg.path]
    }

    private var defaultProbeJSON: String {
        """
        {"streams":[
          {"index":0,"codec_name":"h264","codec_tag_string":"avc1","codec_type":"video","disposition":{"attached_pic":0}},
          {"index":1,"codec_name":"aac","codec_type":"audio","channels":2}
        ],"format":{"duration":"10.0"}}
        """
    }
}
