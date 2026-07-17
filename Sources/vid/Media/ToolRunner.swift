import Subprocess

struct ToolRunner: Sendable {
    func capture(_ tool: String, arguments: [String]) async throws -> String {
        let execution = try await Subprocess.run(
            .name(tool),
            arguments: Arguments(arguments),
            output: .string(limit: 4 * 1_024 * 1_024),
            error: .string(limit: 1_024 * 1_024),
        )

        guard execution.terminationStatus.isSuccess else {
            throw VidError.processFailed(
                tool: tool,
                status: execution.terminationStatus.description,
                diagnostic: execution.standardError?.trimmingCharacters(in: .whitespacesAndNewlines),
            )
        }

        return execution.standardOutput ?? ""
    }

    func stream(_ tool: String, arguments: [String]) async throws {
        print(CommandPreview.render(tool: tool, arguments: arguments))

        let execution = try await Subprocess.run(
            .name(tool),
            arguments: Arguments(arguments),
            output: .currentStandardOutput,
            error: .currentStandardError,
        )

        guard execution.terminationStatus.isSuccess else {
            throw VidError.processFailed(
                tool: tool,
                status: execution.terminationStatus.description,
                diagnostic: nil,
            )
        }
    }
}

private enum CommandPreview {
    static func render(tool: String, arguments: [String]) -> String {
        ([tool] + arguments).map(quote).joined(separator: " ")
    }

    private static func quote(_ argument: String) -> String {
        guard argument.contains(where: { $0.isWhitespace || "'\"\\$".contains($0) }) else {
            return argument
        }

        return "'\(argument.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
