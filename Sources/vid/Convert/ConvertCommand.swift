import ArgumentParser
import Foundation

/// Converts an existing file or media library to Apple-compatible MP4 files.
struct ConvertCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "convert",
        abstract: "Convert existing media to Apple-compatible MP4 files.",
    )

    /// A media file or directory to process recursively.
    @Argument(help: "A media file or directory to convert.")
    var path: String

    /// The video codec produced when re-encoding is required.
    @Option(name: .long, help: "Target video codec: h264 or h265.")
    var videoCodec: ConversionVideoCodec = .h265

    mutating func run() async throws {
        let progressReporter = TerminalConversionProgressReporter()
        let converter = MediaConverter(
            reportProgress: { progress in
                await progressReporter.report(progress)
            }
        )
        _ = try await converter.convert(path: path, videoCodec: videoCodec)
    }
}
