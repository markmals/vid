import Foundation

/// A decoded summary of the streams contained in a media file, as reported by
/// ffprobe.
struct MediaProbe: Decodable, Sendable {
    /// All streams reported for the media file, in ffprobe's order.
    let streams: [MediaStream]

    /// The audio streams contained in the media file.
    /// - Complexity: O(n), where n is the number of streams.
    var audioStreams: [MediaStream] {
        streams.filter { $0.codecType == "audio" }
    }

    /// The subtitle streams encoded as bitmap (image-based) subtitles.
    /// - Complexity: O(n), where n is the number of streams.
    var bitmapSubtitleStreams: [MediaStream] {
        subtitleStreams.filter(\.isBitmapSubtitle)
    }

    /// The first genuine video stream, excluding attached-picture (cover art)
    /// streams, or `nil` if the file has none.
    /// - Complexity: O(n), where n is the number of streams.
    var firstVideoStream: MediaStream? {
        streams.first { $0.codecType == "video" && $0.disposition?.attachedPicture != 1 }
    }

    /// The subtitle streams contained in the media file.
    /// - Complexity: O(n), where n is the number of streams.
    var subtitleStreams: [MediaStream] {
        streams.filter { $0.codecType == "subtitle" }
    }

    /// The subtitle streams encoded as text (non-bitmap) subtitles.
    /// - Complexity: O(n), where n is the number of streams.
    var textSubtitleStreams: [MediaStream] {
        subtitleStreams.filter { !$0.isBitmapSubtitle }
    }
}

/// A single stream within a media file, as decoded from ffprobe's JSON output.
struct MediaStream: Decodable, Sendable {
    /// The disposition flags describing a stream's role.
    struct Disposition: Decodable, Sendable {
        /// Whether the stream is an attached picture (cover art); `1` when set.
        let attachedPicture: Int?

        /// Maps disposition properties to ffprobe's JSON keys.
        enum CodingKeys: String, CodingKey {
            /// The `attached_pic` disposition flag.
            case attachedPicture = "attached_pic"
        }
    }

    /// The metadata tags attached to a stream.
    struct Tags: Decodable, Sendable {
        /// The stream's language tag, if present (e.g. `"eng"`).
        let language: String?
    }

    /// The stream's index within the media file.
    let index: Int
    /// The name of the codec used by the stream, if reported.
    let codecName: String?
    /// The stream's media type, such as `"video"`, `"audio"`, or `"subtitle"`.
    let codecType: String?
    /// The stream's disposition flags, if reported.
    let disposition: Disposition?
    /// The stream's metadata tags, if reported.
    let tags: Tags?

    /// Whether the stream is a bitmap (image-based) subtitle.
    var isBitmapSubtitle: Bool {
        guard let codecName else {
            return false
        }

        return Self.bitmapSubtitleCodecs.contains(codecName)
    }

    /// The stream's language code, lowercased, or `nil` if untagged.
    /// - Complexity: O(n), where n is the length of the language code.
    var language: String? {
        tags?.language?.lowercased()
    }

    /// The file extension to use when extracting this subtitle stream to a
    /// sidecar file.
    var subtitleFileExtension: String {
        switch codecName {
        case "hdmv_pgs_subtitle": "sup"
        case "xsub": "xsub"
        default: "sub"
        }
    }

    /// Maps stream properties to ffprobe's JSON keys.
    enum CodingKeys: String, CodingKey {
        /// The `codec_name` field.
        case codecName = "codec_name"
        /// The `codec_type` field.
        case codecType = "codec_type"
        /// The `disposition` field.
        case disposition
        /// The `index` field.
        case index
        /// The `tags` field.
        case tags
    }

    private static let bitmapSubtitleCodecs: Set<String> = [
        "dvb_subtitle",
        "dvd_subtitle",
        "hdmv_pgs_subtitle",
        "xsub",
    ]
}

/// Probes media files with ffprobe to obtain their stream information.
struct MediaProber: Sendable {
    /// The tool runner used to invoke ffprobe.
    let runner: ToolRunner

    /// Creates a prober.
    /// - Parameter runner: The tool runner used to invoke ffprobe.
    init(runner: ToolRunner = ToolRunner()) {
        self.runner = runner
    }

    /// Probes a media file and returns its decoded stream information.
    ///
    /// Runs `ffprobe` as a subprocess to read the file's stream metadata as JSON
    /// and decodes it.
    /// - Parameter file: The media file to probe.
    /// - Returns: The decoded ``MediaProbe`` describing the file's streams.
    /// - Throws: ``VidError/unreadableProbe(path:)`` if ffprobe's output cannot be
    ///   decoded, ``VidError/noVideoStream(path:)`` if the file contains no video
    ///   stream, or ``VidError/processFailed(tool:status:diagnostic:)`` if ffprobe
    ///   exits unsuccessfully.
    func probe(_ file: URL) async throws -> MediaProbe {
        let output = try await runner.captureOutput(
            of: "ffprobe",
            arguments: [
                "-v", "error",
                "-show_entries",
                "stream=index,codec_name,codec_type,disposition:stream_tags=language",
                "-of", "json",
                file.path,
            ],
        )

        guard let probe = try? JSONDecoder().decode(MediaProbe.self, from: Data(output.utf8)) else {
            throw VidError.unreadableProbe(path: file.path)
        }
        guard probe.firstVideoStream != nil else {
            throw VidError.noVideoStream(path: file.path)
        }

        return probe
    }
}
