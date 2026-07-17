import Foundation

struct OutputPolicy: Sendable {
    let outputDirectory: URL?
    let overwrite: Bool
    let removeSource: Bool
    let replace: Bool
}

struct OutputTransaction: Sendable {
    let finalURL: URL
    let sourceURL: URL
    let temporaryURL: URL

    private let shouldRemoveSource: Bool

    init(
        sourceURL: URL,
        operationName: String,
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
                throw VidError.invalidOutputDirectory(outputDirectory.path)
            }
        }

        let standardizedSourceURL = sourceURL.standardizedFileURL
        let sourceDirectory = standardizedSourceURL.deletingLastPathComponent()
        let destinationDirectory = policy.outputDirectory?.standardizedFileURL ?? sourceDirectory
        let baseName = standardizedSourceURL.deletingPathExtension().lastPathComponent
        let mp4URL = destinationDirectory.appendingPathComponent("\(baseName).mp4")

        if policy.replace {
            guard policy.outputDirectory == nil else {
                throw VidError.invalidOutputDirectory(
                    "--replace cannot be combined with --output-directory",
                )
            }
            finalURL = mp4URL
        } else if mp4URL.standardizedFileURL == standardizedSourceURL {
            finalURL = destinationDirectory.appendingPathComponent(
                "\(baseName).\(operationName).mp4",
            )
        } else {
            finalURL = mp4URL
        }

        if FileManager.default.fileExists(atPath: finalURL.path),
            finalURL != standardizedSourceURL,
            !policy.overwrite
        {
            throw VidError.outputExists(finalURL.path)
        }

        let temporaryName = ".\(baseName).vid-\(UUID().uuidString).partial.mp4"
        temporaryURL = destinationDirectory.appendingPathComponent(temporaryName)
        shouldRemoveSource = policy.removeSource || policy.replace
        self.sourceURL = standardizedSourceURL
    }

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

    func discardTemporaryOutput() {
        guard FileManager.default.fileExists(atPath: temporaryURL.path) else {
            return
        }

        try? FileManager.default.removeItem(at: temporaryURL)
    }

    private func ensureNonEmptyOutput() throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: temporaryURL.path)
        guard let fileSize = attributes[.size] as? NSNumber, fileSize.int64Value > 0 else {
            throw VidError.emptyOutput(temporaryURL.path)
        }
    }
}
