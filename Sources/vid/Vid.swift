import ArgumentParser

@main
struct Vid: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vid",
        abstract: "Convert and organize media with FFmpeg.",
        version: "0.1.0",
        subcommands: [
            RemuxCommand.self,
            TagCommand.self,
            EncodeCommand.self,
            RepairCommand.self,
            SubtitlesCommand.self,
        ],
    )
}
