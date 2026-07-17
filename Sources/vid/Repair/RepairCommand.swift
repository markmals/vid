import ArgumentParser

struct RepairCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "repair",
        abstract: "Deinterlace and re-encode problematic video as H.264/AAC MP4.",
    )

    @OptionGroup var input: MediaInputOptions
    @OptionGroup var output: MediaOutputOptions

    mutating func run() async throws {
        let processor = MediaProcessor()
        let outputPolicy = try output.policy()
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
