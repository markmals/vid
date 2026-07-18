import ArgumentParser

/// The `vid` executable entry point that dispatches to media subcommands.
@main
struct Vid: AsyncParsableCommand {
    /// Declares the root command, its version, and the top-level subcommands.
    static let configuration = CommandConfiguration(
        commandName: "vid",
        abstract: "Convert and organize media with FFmpeg.",
        version: "0.1.0",
        subcommands: [
            ConvertCommand.self,
            RemuxCommand.self,
            TagCommand.self,
            EncodeCommand.self,
            RepairCommand.self,
            SubtitlesCommand.self,
        ],
    )
}
