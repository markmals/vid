import Foundation

/// A non-zero termination reported by an external command.
public struct CommandExecutionError: Error, LocalizedError, Sendable {
    /// The executable name supplied to the command runner.
    public let tool: String
    /// The subprocess termination status description.
    public let status: String
    /// Captured diagnostic output, when the execution mode collects it.
    public let diagnostic: String?

    /// Creates an external-command failure.
    public init(tool: String, status: String, diagnostic: String?) {
        self.tool = tool
        self.status = status
        self.diagnostic = diagnostic
    }

    /// A concise description suitable for command-line display.
    ///
    /// - Complexity: O(n), where n is the combined length of the stored strings.
    public var errorDescription: String? {
        if let diagnostic, !diagnostic.isEmpty {
            "\(tool) \(status): \(diagnostic)"
        } else {
            "\(tool) \(status)."
        }
    }
}
