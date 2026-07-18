import ArgumentParser
import MediaProcessing
import MediaRepair

/// Deinterlaces and re-encodes problematic videos as H.264/AAC MP4 files.
struct RepairCommand: AsyncParsableCommand {
    /// Declares the `repair` command and its user-facing description.
    static let configuration = CommandConfiguration(
        commandName: "repair",
        abstract: "Deinterlace and re-encode problematic video as H.264/AAC MP4.",
    )

    /// Input file discovery options shared across media commands.
    @OptionGroup var input: MediaInputOptions

    /// Output destination and disposition options shared across media commands.
    @OptionGroup var output: MediaOutputOptions

    /// Repairs each discovered input by re-encoding it to H.264/AAC MP4.
    ///
    /// - Throws: Any error thrown while building the output policy, discovering
    ///   inputs, or processing a file. Each processed file is written to disk
    ///   according to the resolved output policy.
    mutating func run() async throws {
        let processor = MediaProcessor()
        let outputPolicy = try output.makeOutputPolicy()
        let plan = RepairPlan()

        for file in try input.files() {
            _ = try await processor.process(
                file,
                outputPolicy: outputPolicy,
                plan: plan,
            )
        }
    }
}
