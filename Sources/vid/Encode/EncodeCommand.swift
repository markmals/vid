import ArgumentParser
import Foundation

/// The `encode` command, which re-encodes video as HEVC in an Apple-compatible MP4.
struct EncodeCommand: AsyncParsableCommand {
    /// The Argument Parser configuration describing the `encode` subcommand.
    static let configuration = CommandConfiguration(
        commandName: "encode",
        abstract: "Encode video as HEVC in an Apple-compatible MP4.",
    )

    /// The input file and directory selection arguments.
    @OptionGroup var input: MediaInputOptions
    /// The output placement and source-cleanup arguments.
    @OptionGroup var output: MediaOutputOptions

    /// How subtitle tracks are handled during encoding.
    @Option(name: .long, help: "Subtitle handling: extract, text, or none.")
    var subtitles: SubtitleHandlingArgument = .extract

    /// The audio codec applied to the encoded output.
    @Option(name: .long, help: "Audio codec: eac3, aac, or copy.")
    var audioCodec: AudioCodecArgument = .eac3

    /// The audio bitrate used when audio is re-encoded.
    @Option(name: .long, help: "Audio bitrate used when audio is encoded.")
    var audioBitrate = "320k"

    /// The HEVC constant rate factor, from 0 (best quality) through 51.
    @Option(name: .long, help: "HEVC constant rate factor from 0 through 51.")
    var crf = 23

    /// The libx265 encoding preset controlling the speed/quality tradeoff.
    @Option(name: .long, help: "libx265 encoding preset.")
    var preset = "medium"

    /// Language codes whose audio tracks are excluded from the output.
    @Option(
        name: .long,
        help: "Exclude audio tracks with this language code. Repeat for multiple codes.")
    var excludeAudioLanguage: [String] = []

    /// Whether track dispositions are reset so the first audio and English subtitle tracks become default.
    @Flag(
        name: .customLong("normalize-dispositions"),
        help: "Reset defaults, then make the first audio and English subtitle tracks default.")
    var shouldNormalizeDispositions = false

    /// Whether inputs whose primary video stream is already HEVC are skipped.
    @Flag(
        name: .customLong("skip-hevc"),
        help: "Skip inputs whose primary video stream is already HEVC.")
    var shouldSkipHEVCInputs = false

    /// Validates option values before the command runs.
    ///
    /// - Throws: `ValidationError` when `--crf` is outside the range 0 through 51.
    mutating func validate() throws {
        guard (0...51).contains(crf) else {
            throw ValidationError("--crf must be between 0 and 51.")
        }
    }

    /// Encodes each discovered input, skipping sources already in HEVC when requested.
    ///
    /// - Throws: Any error raised while discovering inputs, probing, or processing files.
    mutating func run() async throws {
        let settings = EncodeSettings(
            audioEncoding: audioCodec.encoding(bitrate: audioBitrate),
            crf: crf,
            excludedAudioLanguages: Set(excludeAudioLanguage.map { $0.lowercased() }),
            shouldNormalizeDispositions: shouldNormalizeDispositions,
            preset: preset,
            subtitleHandling: subtitles.handling,
        )
        let plan = EncodePlan(settings: settings)
        let processor = MediaProcessor()
        let outputPolicy = try output.makeOutputPolicy()

        for file in try input.files() {
            let probe = shouldSkipHEVCInputs ? try await processor.prober.probe(file) : nil
            if probe?.firstVideoStream?.codecName == "hevc" {
                print("Skipping \(file.path); video is already HEVC")
                continue
            }

            _ = try await processor.process(
                file,
                outputPolicy: outputPolicy,
                plan: plan,
                probe: probe,
            )
        }
    }
}
