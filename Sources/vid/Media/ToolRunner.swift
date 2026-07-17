import Subprocess

/// Runs external command-line tools as subprocesses, either capturing their
/// output or streaming it to the current terminal.
struct ToolRunner: Sendable {
    /// Runs a tool to completion and returns its standard output.
    ///
    /// Spawns `tool` as a subprocess with the given arguments, buffering both
    /// standard output (up to 4 MiB) and standard error (up to 1 MiB) in memory.
    /// - Parameters:
    ///   - tool: The name of the executable to locate on `PATH` and run.
    ///   - arguments: The command-line arguments passed to the tool.
    /// - Returns: The captured standard output, or the empty string if the tool
    ///   produced none.
    /// - Throws: ``VidError/processFailed(tool:status:diagnostic:)`` if the tool
    ///   exits with a non-zero termination status.
    func captureOutput(of tool: String, arguments: [String]) async throws -> String {
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

    /// Runs a tool to completion, streaming its output directly to the terminal.
    ///
    /// Prints a shell-style preview of the command, then spawns `tool` as a
    /// subprocess whose standard output and standard error are inherited from
    /// the current process, so its progress is visible live to the user.
    /// - Parameters:
    ///   - tool: The name of the executable to locate on `PATH` and run.
    ///   - arguments: The command-line arguments passed to the tool.
    /// - Throws: ``VidError/processFailed(tool:status:diagnostic:)`` if the tool
    ///   exits with a non-zero termination status.
    func streamOutput(of tool: String, arguments: [String]) async throws {
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
