import ArgumentParser
import Foundation

struct EncodeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "encode",
        abstract: "Encode video as HEVC in an Apple-compatible MP4.",
    )

    @OptionGroup var input: MediaInputOptions
    @OptionGroup var output: MediaOutputOptions

    @Option(name: .long, help: "Subtitle handling: extract, text, or none.")
    var subtitles: SubtitleHandlingArgument = .extract

    @Option(name: .long, help: "Audio codec: eac3, aac, or copy.")
    var audioCodec: AudioCodecArgument = .eac3

    @Option(name: .long, help: "Audio bitrate used when audio is encoded.")
    var audioBitrate = "320k"

    @Option(name: .long, help: "HEVC constant rate factor from 0 through 51.")
    var crf = 23

    @Option(name: .long, help: "libx265 encoding preset.")
    var preset = "medium"

    @Option(
        name: .long,
        help: "Exclude audio tracks with this language code. Repeat for multiple codes.")
    var excludeAudioLanguage: [String] = []

    @Flag(
        name: .long,
        help: "Reset defaults, then make the first audio and English subtitle tracks default.")
    var normalizeDispositions = false

    @Flag(name: .long, help: "Skip inputs whose primary video stream is already HEVC.")
    var skipHEVC = false

    mutating func validate() throws {
        guard (0...51).contains(crf) else {
            throw ValidationError("--crf must be between 0 and 51.")
        }
    }

    mutating func run() async throws {
        let settings = EncodeSettings(
            audioEncoding: audioCodec.encoding(bitrate: audioBitrate),
            crf: crf,
            excludedAudioLanguages: Set(excludeAudioLanguage.map { $0.lowercased() }),
            normalizeDispositions: normalizeDispositions,
            preset: preset,
            subtitleHandling: subtitles.handling,
        )
        let plan = EncodePlan(settings: settings)
        let processor = MediaProcessor()
        let outputPolicy = try output.policy()

        for file in try input.files() {
            let probe = skipHEVC ? try await processor.prober.probe(file) : nil
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
