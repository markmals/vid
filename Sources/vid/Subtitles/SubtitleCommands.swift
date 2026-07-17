import ArgumentParser
import Foundation

struct SubtitlesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "subtitles",
        abstract: "Manage subtitle tracks.",
        subcommands: [AddSubtitleCommand.self, AddMatchingSubtitlesCommand.self],
    )
}

struct AddSubtitleCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add an external text subtitle track to one video.",
    )

    @Argument(help: "Video that will receive the subtitle track.")
    var video: String

    @Argument(help: "External text subtitle file.")
    var subtitle: String

    @OptionGroup var output: MediaOutputOptions

    @Option(name: .long, help: "ISO 639 subtitle language code.")
    var language = "eng"

    @Option(name: .long, help: "Subtitle track title.")
    var title = "ENG"

    @Flag(name: .long, help: "Permanently remove the external subtitle after success.")
    var removeSubtitle = false

    mutating func run() async throws {
        try await AddSubtitleWorkflow().run(
            video: FilePathResolver.resolve(video),
            subtitle: FilePathResolver.resolve(subtitle),
            outputPolicy: output.policy(),
            language: language,
            title: title,
            removeSubtitle: removeSubtitle,
        )
    }
}

struct AddMatchingSubtitlesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add-matching",
        abstract: "Add same-named external subtitle files to multiple videos.",
    )

    @OptionGroup var input: MediaInputOptions
    @OptionGroup var output: MediaOutputOptions

    @Option(name: .long, help: "Extension of same-named subtitle files.")
    var subtitleExtension = "srt"

    @Option(name: .long, help: "ISO 639 subtitle language code.")
    var language = "eng"

    @Option(name: .long, help: "Subtitle track title.")
    var title = "ENG"

    @Flag(name: .long, help: "Permanently remove external subtitles after success.")
    var removeSubtitles = false

    mutating func run() async throws {
        let outputPolicy = try output.policy()
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
                removeSubtitle: removeSubtitles,
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
            throw VidError.fileDoesNotExist(video.path)
        }
        guard FileManager.default.fileExists(atPath: subtitle.path) else {
            throw VidError.fileDoesNotExist(subtitle.path)
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
