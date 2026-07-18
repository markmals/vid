import ArgumentParser
import Foundation
import MediaDiscovery
import MediaProcessing
import MediaSubtitles

/// Groups the subcommands that add external subtitle tracks to videos.
struct SubtitlesCommand: ParsableCommand {
    /// Declares the `subtitles` command group and its subtitle subcommands.
    static let configuration = CommandConfiguration(
        commandName: "subtitles",
        abstract: "Manage subtitle tracks.",
        subcommands: [AddSubtitleCommand.self, AddMatchingSubtitlesCommand.self],
    )
}

/// Embeds a single external text subtitle file into one video as a new track.
struct AddSubtitleCommand: AsyncParsableCommand {
    /// Declares the `add` subcommand that embeds one subtitle track.
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add an external text subtitle track to one video.",
    )

    /// Path to the video that will receive the subtitle track.
    @Argument(help: "Video that will receive the subtitle track.")
    var video: String

    /// Path to the external text subtitle file to embed.
    @Argument(help: "External text subtitle file.")
    var subtitle: String

    /// Output destination and disposition options shared across media commands.
    @OptionGroup var output: MediaOutputOptions

    /// ISO 639 language code recorded on the embedded subtitle track.
    @Option(name: .long, help: "ISO 639 subtitle language code.")
    var language = "eng"

    /// Human-readable title recorded on the embedded subtitle track.
    @Option(name: .long, help: "Subtitle track title.")
    var title = "ENG"

    /// Whether to delete the external subtitle file after it is successfully embedded.
    ///
    /// Preserves the `--remove-subtitle` flag spelling via an explicit long name.
    @Flag(
        name: .customLong("remove-subtitle"),
        help: "Permanently remove the external subtitle after success.")
    var shouldRemoveSubtitle = false

    /// Resolves the input paths and embeds the subtitle track into the video.
    ///
    /// - Throws: A ``MediaDiscoveryError`` when either resolved path does not exist, a
    ///   `ValidationError` when the video and subtitle resolve to the same file,
    ///   or any error thrown while building the output policy or processing the
    ///   video. When `shouldRemoveSubtitle` is set, a successful embed deletes
    ///   the external subtitle file from disk.
    mutating func run() async throws {
        try await AddSubtitleWorkflow().run(
            video: FilePathResolver.resolvedURL(for: video),
            subtitle: FilePathResolver.resolvedURL(for: subtitle),
            outputPolicy: output.makeOutputPolicy(),
            language: language,
            title: title,
            removeSubtitle: shouldRemoveSubtitle,
        )
    }
}

/// Embeds same-named external subtitle files into multiple videos in one pass.
struct AddMatchingSubtitlesCommand: AsyncParsableCommand {
    /// Declares the `add-matching` subcommand that batch-embeds subtitle tracks.
    static let configuration = CommandConfiguration(
        commandName: "add-matching",
        abstract: "Add same-named external subtitle files to multiple videos.",
    )

    /// Input file discovery options shared across media commands.
    @OptionGroup var input: MediaInputOptions

    /// Output destination and disposition options shared across media commands.
    @OptionGroup var output: MediaOutputOptions

    /// File extension of the same-named subtitle file expected beside each video.
    @Option(name: .long, help: "Extension of same-named subtitle files.")
    var subtitleExtension = "srt"

    /// ISO 639 language code recorded on each embedded subtitle track.
    @Option(name: .long, help: "ISO 639 subtitle language code.")
    var language = "eng"

    /// Human-readable title recorded on each embedded subtitle track.
    @Option(name: .long, help: "Subtitle track title.")
    var title = "ENG"

    /// Whether to delete each matched external subtitle file after it is embedded.
    ///
    /// Preserves the `--remove-subtitles` flag spelling via an explicit long name.
    @Flag(
        name: .customLong("remove-subtitles"),
        help: "Permanently remove external subtitles after success.")
    var shouldRemoveMatchedSubtitles = false

    /// Embeds the matching subtitle file for each discovered video.
    ///
    /// For every input video, this looks for a sibling file with the same base
    /// name and the configured subtitle extension and embeds it as a track.
    ///
    /// - Throws: A `ValidationError` when `--subtitle-extension` is empty, and
    ///   any error thrown while discovering inputs, building the output policy,
    ///   or processing a video. When `shouldRemoveMatchedSubtitles` is set, each
    ///   successful embed deletes the matched subtitle file from disk.
    mutating func run() async throws {
        let outputPolicy = try output.makeOutputPolicy()
        let workflow = AddSubtitleWorkflow()
        let normalizedExtension = subtitleExtension.trimmingCharacters(
            in: CharacterSet(charactersIn: "."))

        guard !normalizedExtension.isEmpty else {
            throw ValidationError("--subtitle-extension cannot be empty.")
        }

        for video in try input.files() {
            let subtitle = video.deletingPathExtension().appendingPathExtension(normalizedExtension)
            try await workflow.run(
                video: video,
                subtitle: subtitle,
                outputPolicy: outputPolicy,
                language: language,
                title: title,
                removeSubtitle: shouldRemoveMatchedSubtitles,
            )
        }
    }
}

private struct AddSubtitleWorkflow {
    let processor = MediaProcessor()

    func run(
        video: URL,
        subtitle: URL,
        outputPolicy: OutputPolicy,
        language: String,
        title: String,
        removeSubtitle: Bool,
    ) async throws {
        guard FileManager.default.fileExists(atPath: video.path) else {
            throw MediaDiscoveryError.fileDoesNotExist(path: video.path)
        }
        guard FileManager.default.fileExists(atPath: subtitle.path) else {
            throw MediaDiscoveryError.fileDoesNotExist(path: subtitle.path)
        }
        guard video.standardizedFileURL != subtitle.standardizedFileURL else {
            throw ValidationError("The video and subtitle must be different files.")
        }

        _ = try await processor.process(
            video,
            outputPolicy: outputPolicy,
            plan: AddSubtitlePlan(
                subtitle: subtitle,
                language: language,
                title: title,
            ),
        )

        if removeSubtitle {
            try FileManager.default.removeItem(at: subtitle)
        }
    }
}
