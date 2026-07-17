import ArgumentParser
import Foundation

struct RemuxCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remux",
        abstract: "Repackage media as MP4 without re-encoding video.",
    )

    @OptionGroup var input: MediaInputOptions
    @OptionGroup var output: MediaOutputOptions

    @Option(name: .long, help: "Subtitle handling: text, extract, or none.")
    var subtitles: SubtitleHandlingArgument = .text

    @Flag(name: .long, help: "Apply Apple-compatible HEVC and Dolby codec tags.")
    var appleCompatible = false

    @Option(name: .long, help: "Audio codec: copy, eac3, or aac.")
    var audioCodec: AudioCodecArgument = .copy

    @Option(name: .long, help: "Audio bitrate used when audio is encoded.")
    var audioBitrate = "320k"

    mutating func run() async throws {
        try await RemuxWorkflow().run(
            files: input.files(),
            outputPolicy: output.policy(),
            plan: RemuxPlan(
                operationName: "remuxed",
                settings: RemuxSettings(
                    appleCompatible: appleCompatible,
                    audioEncoding: audioCodec.encoding(bitrate: audioBitrate),
                    subtitleHandling: subtitles.handling,
                ),
            ),
        )
    }
}

struct TagCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tag",
        abstract: "Create an Apple-compatible MP4 without re-encoding video.",
    )

    @OptionGroup var input: MediaInputOptions
    @OptionGroup var output: MediaOutputOptions

    @Option(name: .long, help: "Subtitle handling: extract, text, or none.")
    var subtitles: SubtitleHandlingArgument = .extract

    @Option(name: .long, help: "Audio codec: copy, eac3, or aac.")
    var audioCodec: AudioCodecArgument = .copy

    @Option(name: .long, help: "Audio bitrate used when audio is encoded.")
    var audioBitrate = "320k"

    mutating func run() async throws {
        try await RemuxWorkflow().run(
            files: input.files(),
            outputPolicy: output.policy(),
            plan: RemuxPlan(
                operationName: "tagged",
                settings: RemuxSettings(
                    appleCompatible: true,
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
