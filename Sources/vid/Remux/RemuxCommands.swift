import ArgumentParser
import Foundation
import MediaProcessing
import MediaRemux

/// The `remux` command, which repackages media as MP4 without re-encoding video.
struct RemuxCommand: AsyncParsableCommand {
    /// The Argument Parser configuration describing the `remux` subcommand.
    static let configuration = CommandConfiguration(
        commandName: "remux",
        abstract: "Repackage media as MP4 without re-encoding video.",
    )

    /// The input file and directory selection arguments.
    @OptionGroup var input: MediaInputOptions
    /// The output placement and source-cleanup arguments.
    @OptionGroup var output: MediaOutputOptions

    /// How subtitle tracks are handled during remuxing.
    @Option(name: .long, help: "Subtitle handling: text, extract, or none.")
    var subtitles: SubtitleHandlingArgument = .text

    /// Whether Apple-compatible HEVC and Dolby codec tags are applied.
    @Flag(
        name: .customLong("apple-compatible"),
        help: "Apply Apple-compatible HEVC and Dolby codec tags.")
    var isAppleCompatible = false

    /// The audio codec applied to the remuxed output.
    @Option(name: .long, help: "Audio codec: copy, eac3, or aac.")
    var audioCodec: AudioCodecArgument = .copy

    /// The audio bitrate used when audio is re-encoded.
    @Option(name: .long, help: "Audio bitrate used when audio is encoded.")
    var audioBitrate = "320k"

    /// Remuxes each discovered input into an MP4 container.
    ///
    /// - Throws: Any error raised while discovering inputs or processing files.
    mutating func run() async throws {
        try await RemuxWorkflow().run(
            files: input.files(),
            outputPolicy: output.makeOutputPolicy(),
            plan: RemuxPlan(
                outputFilenameSuffix: "remuxed",
                settings: RemuxSettings(
                    isAppleCompatible: isAppleCompatible,
                    audioEncoding: audioCodec.encoding(bitrate: audioBitrate),
                    subtitleHandling: subtitles.handling,
                ),
            ),
        )
    }
}

/// The `tag` command, which creates an Apple-compatible MP4 without re-encoding video.
struct TagCommand: AsyncParsableCommand {
    /// The Argument Parser configuration describing the `tag` subcommand.
    static let configuration = CommandConfiguration(
        commandName: "tag",
        abstract: "Create an Apple-compatible MP4 without re-encoding video.",
    )

    /// The input file and directory selection arguments.
    @OptionGroup var input: MediaInputOptions
    /// The output placement and source-cleanup arguments.
    @OptionGroup var output: MediaOutputOptions

    /// How subtitle tracks are handled during tagging.
    @Option(name: .long, help: "Subtitle handling: extract, text, or none.")
    var subtitles: SubtitleHandlingArgument = .extract

    /// The audio codec applied to the tagged output.
    @Option(name: .long, help: "Audio codec: copy, eac3, or aac.")
    var audioCodec: AudioCodecArgument = .copy

    /// The audio bitrate used when audio is re-encoded.
    @Option(name: .long, help: "Audio bitrate used when audio is encoded.")
    var audioBitrate = "320k"

    /// Tags each discovered input as an Apple-compatible MP4.
    ///
    /// - Throws: Any error raised while discovering inputs or processing files.
    mutating func run() async throws {
        try await RemuxWorkflow().run(
            files: input.files(),
            outputPolicy: output.makeOutputPolicy(),
            plan: RemuxPlan(
                outputFilenameSuffix: "tagged",
                settings: RemuxSettings(
                    isAppleCompatible: true,
                    audioEncoding: audioCodec.encoding(bitrate: audioBitrate),
                    subtitleHandling: subtitles.handling,
                ),
            ),
        )
    }
}

private struct RemuxWorkflow {
    let processor = MediaProcessor()

    func run(
        files: [URL],
        outputPolicy: OutputPolicy,
        plan: RemuxPlan,
    ) async throws {
        for file in files {
            _ = try await processor.process(
                file,
                outputPolicy: outputPolicy,
                plan: plan,
            )
        }
    }
}
