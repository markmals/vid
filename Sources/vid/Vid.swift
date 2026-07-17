import ArgumentParser

@main
struct Vid: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vid",
        abstract: "Convert and organize media with FFmpeg.",
        subcommands: [
            RemuxCommand.self,
            TagCommand.self,
            EncodeCommand.self,
            RepairCommand.self,
            SubtitlesCommand.self,
        ],
    )
}
