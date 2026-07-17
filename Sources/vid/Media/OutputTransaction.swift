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
    /// The temporary file the operation writes to before commit.
    let temporaryURL: URL

    private let shouldRemoveSource: Bool

    /// Resolves the final and temporary output locations for a source file.
    ///
    /// - Parameters:
    ///   - sourceURL: The source media file being processed.
    ///   - outputFilenameSuffix: The suffix inserted before the extension when
    ///     the default `.mp4` output would collide with the source.
    ///   - policy: The resolved output behavior controlling directory,
    ///     overwrite, removal, and in-place replacement.
    /// - Throws: ``VidError/incompatibleOutputOptions(reason:)`` when in-place
    ///   replacement is combined with an output directory;
    ///   ``VidError/invalidOutputDirectory(path:)`` when the output directory
    ///   does not exist; ``VidError/outputExists(path:)`` when the destination
    ///   already exists and overwriting is not permitted.
    init(
        sourceURL: URL,
        outputFilenameSuffix: String,
        policy: OutputPolicy,
    ) throws {
        if let outputDirectory = policy.outputDirectory {
            var isDirectory: ObjCBool = false
            guard
                FileManager.default.fileExists(
                    atPath: outputDirectory.path,
                    isDirectory: &isDirectory,
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
                    reason: "--replace cannot be combined with --output-directory.",
                )
            }
            finalURL = mp4URL
        } else if mp4URL.standardizedFileURL == standardizedSourceURL {
            finalURL = destinationDirectory.appendingPathComponent(
                "\(baseName).\(outputFilenameSuffix).mp4",
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

        let temporaryName = ".\(baseName).vid-\(UUID().uuidString).partial.mp4"
        temporaryURL = destinationDirectory.appendingPathComponent(temporaryName)
        shouldRemoveSource = policy.shouldRemoveSource || policy.shouldReplaceInput
        self.sourceURL = standardizedSourceURL
    }

    /// Promotes the temporary output to its final location and, when requested,
    /// removes the source file.
    ///
    /// The temporary file replaces any existing file at the destination, or is
    /// moved into place when none exists. The source is removed only when the
    /// policy requested removal, the source differs from the destination, and
    /// the source still exists.
    ///
    /// - Throws: ``VidError/emptyOutput(path:)`` when the temporary output is
    ///   empty, or a filesystem error if the move, replace, or removal fails.
    func commit() throws {
        try ensureNonEmptyOutput()

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: finalURL.path) {
            _ = try fileManager.replaceItemAt(finalURL, withItemAt: temporaryURL)
        } else {
            try fileManager.moveItem(at: temporaryURL, to: finalURL)
        }

        if shouldRemoveSource, sourceURL != finalURL,
            fileManager.fileExists(atPath: sourceURL.path)
        {
            try fileManager.removeItem(at: sourceURL)
        }
    }

    /// Deletes the temporary output file if it exists, discarding an abandoned
    /// operation. Any removal failure is ignored.
    func discardTemporaryOutput() {
        guard FileManager.default.fileExists(atPath: temporaryURL.path) else {
            return
        }

        try? FileManager.default.removeItem(at: temporaryURL)
    }

    private func ensureNonEmptyOutput() throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: temporaryURL.path)
        guard let fileSize = attributes[.size] as? NSNumber, fileSize.int64Value > 0 else {
            throw VidError.emptyOutput(path: temporaryURL.path)
        }
    }
}
