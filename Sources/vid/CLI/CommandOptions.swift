import ArgumentParser
import Foundation
import MediaDiscovery
import MediaProcessing

/// Command-line arguments that select the media files a command operates on.
struct MediaInputOptions: ParsableArguments {
    /// The media files or directories supplied as positional arguments.
    @Argument(help: "One or more media files or directories.")
    var paths: [String] = []

    /// Whether supplied directories are searched recursively for media files.
    @Flag(
        name: [.customShort("r"), .customLong("recursive")],
        help: "Descend into supplied directories.")
    var includesSubdirectories = false

    /// Resolves the supplied paths into concrete media file URLs.
    ///
    /// - Returns: Every discovered media file, descending into directories when
    ///   ``includesSubdirectories`` is set.
    /// - Throws: `ValidationError` when no paths are supplied, along with any error
    ///   raised while discovering files on disk.
    func files() throws -> [URL] {
        guard !paths.isEmpty else {
            throw ValidationError("Provide at least one media file or directory.")
        }
        return try InputDiscovery().mediaFiles(at: paths, recursive: includesSubdirectories)
    }
}

/// Command-line arguments that control where and how command outputs are written.
struct MediaOutputOptions: ParsableArguments {
    /// An existing directory that receives outputs instead of each source's directory.
    @Option(name: .long, help: "Write outputs to this existing directory.")
    var outputDirectory: String?

    /// Whether an MP4 input is replaced in place and other source containers removed on success.
    @Flag(
        name: .customLong("replace"),
        help: "Replace an MP4 input in place and remove other source containers after success.")
    var shouldReplaceInput = false

    /// Whether each source file is permanently removed after its output completes.
    @Flag(
        name: .customLong("remove-source"),
        help: "Permanently remove each source after its output is complete.")
    var shouldRemoveSource = false

    /// Whether existing output and extracted subtitle files are overwritten.
    @Flag(
        name: .customLong("overwrite"),
        help: "Replace existing output and extracted subtitle files.")
    var shouldOverwriteExistingOutput = false

    /// Builds the output policy that governs file placement and source cleanup.
    ///
    /// - Returns: An ``OutputPolicy`` derived from the supplied output arguments.
    /// - Throws: `ValidationError` when `--replace` is combined with `--output-directory`.
    func makeOutputPolicy() throws -> OutputPolicy {
        if shouldReplaceInput, outputDirectory != nil {
            throw ValidationError("--replace cannot be combined with --output-directory.")
        }

        return OutputPolicy(
            outputDirectory: outputDirectory.map { FilePathResolver.resolvedURL(for: $0) },
            shouldOverwriteExistingOutput: shouldOverwriteExistingOutput,
            shouldRemoveSource: shouldRemoveSource,
            shouldReplaceInput: shouldReplaceInput,
        )
    }
}

/// A selectable audio codec exposed as a command-line option value.
enum AudioCodecArgument: String, CaseIterable, ExpressibleByArgument {
    /// Advanced Audio Coding, encoded at the requested bitrate.
    case aac
    /// Passthrough of the source audio without re-encoding.
    case copy
    /// Enhanced AC-3 (Dolby Digital Plus), encoded at the requested bitrate.
    case eac3

    /// Maps the selected codec to a concrete audio encoding.
    ///
    /// - Parameter bitrate: The target bitrate applied to codecs that re-encode audio.
    /// - Returns: The ``AudioEncoding`` corresponding to this argument.
    func encoding(bitrate: String) -> AudioEncoding {
        switch self {
        case .aac: .aac(bitrate: bitrate)
        case .copy: .copy
        case .eac3: .eac3(bitrate: bitrate)
        }
    }
}

/// A selectable subtitle-handling strategy exposed as a command-line option value.
enum SubtitleHandlingArgument: String, CaseIterable, ExpressibleByArgument {
    /// Extract bitmap subtitle tracks to sidecar files.
    case extract
    /// Drop all subtitle tracks.
    case none
    /// Keep only text subtitle tracks.
    case text

    /// The domain subtitle-handling value corresponding to this argument.
    var handling: SubtitleHandling {
        switch self {
        case .extract: .extractBitmap
        case .none: .none
        case .text: .textOnly
        }
    }
}
