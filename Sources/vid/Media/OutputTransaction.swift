import Foundation

/// The resolved output behavior for a media operation, derived from command
/// options.
struct OutputPolicy: Sendable {
    /// The directory the output should be written to, or `nil` to write beside
    /// the source file.
    let outputDirectory: URL?
    /// Whether an existing file at the destination may be overwritten.
    let shouldOverwriteExistingOutput: Bool
    /// Whether the source file should be removed after a successful commit.
    let shouldRemoveSource: Bool
    /// Whether an MP4 input should be replaced in place and any other source
    /// container should be removed after the MP4 output is committed.
    let shouldReplaceInput: Bool
}

/// A staged filesystem transaction that writes a media operation's output to a
/// temporary file and atomically promotes it to its final location on commit.
///
/// The transaction chooses a collision-free destination, tracks whether the
/// source should be removed, and cleans up the temporary file if the operation
/// is abandoned.
struct OutputTransaction: Sendable {
    /// The destination the committed output will occupy.
    let finalURL: URL
    /// The standardized source file the operation reads from.
    let sourceURL: URL
    /// The temporary file the operation writes before commit.
    let temporaryURL: URL
    /// The private directory containing every intermediate artifact.
    let temporaryDirectoryURL: URL

    private let backupURL: URL
    private let shouldRemoveSource: Bool

    /// Resolves the final output and creates an isolated temporary directory.
    init(
        sourceURL: URL,
        outputFilenameSuffix: String,
        policy: OutputPolicy,
        temporaryDirectoryRoot: URL = FileManager.default.temporaryDirectory,
    ) throws {
        if let outputDirectory = policy.outputDirectory {
            var isDirectory: ObjCBool = false
            guard
                FileManager.default.fileExists(
                    atPath: outputDirectory.path,
                    isDirectory: &isDirectory
                ),
                isDirectory.boolValue
            else {
                throw VidError.invalidOutputDirectory(path: outputDirectory.path)
            }
        }

        let standardizedSourceURL = sourceURL.standardizedFileURL
        let sourceDirectory = standardizedSourceURL.deletingLastPathComponent()
        let destinationDirectory = policy.outputDirectory?.standardizedFileURL ?? sourceDirectory
        let baseName = standardizedSourceURL.deletingPathExtension().lastPathComponent
        let mp4URL = destinationDirectory.appendingPathComponent("\(baseName).mp4")

        if policy.shouldReplaceInput {
            guard policy.outputDirectory == nil else {
                throw VidError.incompatibleOutputOptions(
                    reason: "--replace cannot be combined with --output-directory."
                )
            }
            finalURL = mp4URL
        } else if mp4URL.standardizedFileURL == standardizedSourceURL {
            finalURL = destinationDirectory.appendingPathComponent(
                "\(baseName).\(outputFilenameSuffix).mp4"
            )
        } else {
            finalURL = mp4URL
        }

        if FileManager.default.fileExists(atPath: finalURL.path),
            finalURL != standardizedSourceURL,
            !policy.shouldOverwriteExistingOutput
        {
            throw VidError.outputExists(path: finalURL.path)
        }

        try FileManager.default.createDirectory(
            at: temporaryDirectoryRoot,
            withIntermediateDirectories: true
        )
        temporaryDirectoryURL = temporaryDirectoryRoot.appendingPathComponent(
            "vid-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: temporaryDirectoryURL,
            withIntermediateDirectories: false
        )
        temporaryURL = temporaryDirectoryURL.appendingPathComponent("output.mp4")
        backupURL = temporaryDirectoryURL.appendingPathComponent("replaced-output.mp4")
        shouldRemoveSource = policy.shouldRemoveSource || policy.shouldReplaceInput
        self.sourceURL = standardizedSourceURL
    }

    /// Promotes the validated output and removes the source only after promotion.
    func commit() throws {
        try ensureNonEmptyOutput()
        let fileManager = FileManager.default

        if finalURL == sourceURL {
            _ = try fileManager.replaceItemAt(finalURL, withItemAt: temporaryURL)
            discardTemporaryOutput()
            return
        }

        let replacedExistingOutput = fileManager.fileExists(atPath: finalURL.path)
        if replacedExistingOutput {
            try fileManager.moveItem(at: finalURL, to: backupURL)
        }

        do {
            try fileManager.moveItem(at: temporaryURL, to: finalURL)
            if shouldRemoveSource, fileManager.fileExists(atPath: sourceURL.path) {
                try fileManager.removeItem(at: sourceURL)
            }
        } catch {
            if fileManager.fileExists(atPath: finalURL.path) {
                try? fileManager.removeItem(at: finalURL)
            }
            if replacedExistingOutput, fileManager.fileExists(atPath: backupURL.path) {
                try? fileManager.moveItem(at: backupURL, to: finalURL)
            }
            throw error
        }

        discardTemporaryOutput()
    }

    /// Deletes the complete temporary workspace if it still exists.
    func discardTemporaryOutput() {
        guard FileManager.default.fileExists(atPath: temporaryDirectoryURL.path) else {
            return
        }
        try? FileManager.default.removeItem(at: temporaryDirectoryURL)
    }

    private func ensureNonEmptyOutput() throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: temporaryURL.path)
        guard let fileSize = attributes[.size] as? NSNumber, fileSize.int64Value > 0 else {
            throw VidError.emptyOutput(path: temporaryURL.path)
        }
    }
}
