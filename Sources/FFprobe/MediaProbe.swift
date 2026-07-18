import CommandExecution
import Foundation

/// A decoded summary of the streams contained in a media file, as reported by
/// ffprobe.
public struct MediaProbe: Decodable, Sendable {
    /// Container-level metadata reported for the media file.
    public struct Format: Decodable, Sendable {
        /// Duration in seconds, represented by ffprobe as a decimal string.
        public let duration: String?

        /// Creates container metadata.
        public init(duration: String?) {
            self.duration = duration
        }
    }

    /// All streams reported for the media file, in ffprobe's order.
    public let streams: [MediaStream]
    /// Container-level metadata reported by ffprobe.
    public let format: Format?

    /// Creates a probe from known streams and optional container metadata.
    public init(streams: [MediaStream], format: Format? = nil) {
        self.streams = streams
        self.format = format
    }

    /// The audio streams contained in the media file.
    ///
    /// - Complexity: O(n), where n is the number of streams.
    public var audioStreams: [MediaStream] {
        streams.filter { $0.codecType == "audio" }
    }

    /// The subtitle streams encoded as bitmap subtitles.
    ///
    /// - Complexity: O(n), where n is the number of streams.
    public var bitmapSubtitleStreams: [MediaStream] {
        subtitleStreams.filter(\.isBitmapSubtitle)
    }

    /// Duration in seconds, when ffprobe supplied a finite positive value.
    ///
    /// - Complexity: O(n), where n is the length of the duration string.
    public var durationSeconds: Double? {
        guard let duration = format?.duration,
            let seconds = Double(duration),
            seconds.isFinite,
            seconds > 0
        else {
            return nil
        }
        return seconds
    }

    /// The first genuine video stream, excluding attached cover art.
    ///
    /// - Complexity: O(n), where n is the number of streams.
    public var firstVideoStream: MediaStream? {
        streams.first { $0.codecType == "video" && $0.disposition?.attachedPictureFlag != 1 }
    }

    /// The subtitle streams contained in the media file.
    ///
    /// - Complexity: O(n), where n is the number of streams.
    public var subtitleStreams: [MediaStream] {
        streams.filter { $0.codecType == "subtitle" }
    }

    /// The subtitle streams encoded as text.
    ///
    /// - Complexity: O(n), where n is the number of streams.
    public var textSubtitleStreams: [MediaStream] {
        subtitleStreams.filter { !$0.isBitmapSubtitle }
    }
}

/// A single stream within a media file, as decoded from ffprobe's JSON output.
public struct MediaStream: Decodable, Sendable {
    /// The disposition flags describing a stream's role.
    public struct Disposition: Decodable, Sendable {
        /// The raw ffprobe attached-picture flag: `1` when enabled, `0` when
        /// disabled, or `nil` when the field is absent.
        public let attachedPictureFlag: Int?
        /// The raw ffprobe default-track flag: `1` when enabled, `0` when
        /// disabled, or `nil` when the field is absent.
        public let defaultFlag: Int?
        /// The raw ffprobe forced-subtitle flag: `1` when enabled, `0` when
        /// disabled, or `nil` when the field is absent.
        public let forcedFlag: Int?
        /// The raw ffprobe hearing-impaired flag: `1` when enabled, `0` when
        /// disabled, or `nil` when the field is absent.
        public let hearingImpairedFlag: Int?

        /// Creates stream disposition metadata from raw ffprobe flags.
        ///
        /// Every flag uses `1` for enabled, `0` for disabled, and `nil` when
        /// the corresponding field is absent.
        public init(
            attachedPictureFlag: Int? = nil,
            defaultFlag: Int? = nil,
            forcedFlag: Int? = nil,
            hearingImpairedFlag: Int? = nil,
        ) {
            self.attachedPictureFlag = attachedPictureFlag
            self.defaultFlag = defaultFlag
            self.forcedFlag = forcedFlag
            self.hearingImpairedFlag = hearingImpairedFlag
        }

        enum CodingKeys: String, CodingKey {
            case attachedPictureFlag = "attached_pic"
            case defaultFlag = "default"
            case forcedFlag = "forced"
            case hearingImpairedFlag = "hearing_impaired"
        }
    }

    /// The metadata tags attached to a stream.
    public struct Tags: Decodable, Sendable {
        /// The stream's language tag.
        public let language: String?
        /// The stream's human-readable title.
        public let title: String?

        /// Creates stream tags.
        public init(language: String? = nil, title: String? = nil) {
            self.language = language
            self.title = title
        }
    }

    /// The stream's index within the media file.
    public let index: Int
    /// The name of the codec used by the stream.
    public let codecName: String?
    /// The MP4 codec tag reported for the stream.
    public let codecTagString: String?
    /// The stream's media type.
    public let codecType: String?
    /// The number of audio channels.
    public let channels: Int?
    /// The stream's disposition flags.
    public let disposition: Disposition?
    /// The stream's metadata tags.
    public let tags: Tags?

    /// Creates stream metadata.
    public init(
        index: Int,
        codecName: String?,
        codecType: String?,
        disposition: Disposition?,
        tags: Tags?,
        codecTagString: String? = nil,
        channels: Int? = nil,
    ) {
        self.index = index
        self.codecName = codecName
        self.codecTagString = codecTagString
        self.codecType = codecType
        self.channels = channels
        self.disposition = disposition
        self.tags = tags
    }

    /// Whether the stream is a bitmap subtitle.
    public var isBitmapSubtitle: Bool {
        guard let codecName else {
            return false
        }
        return Self.bitmapSubtitleCodecs.contains(codecName)
    }

    /// The stream's language code, lowercased.
    ///
    /// - Complexity: O(n), where n is the length of the language tag.
    public var language: String? {
        tags?.language?.lowercased()
    }

    /// The file extension used when extracting this subtitle stream.
    public var subtitleFileExtension: String {
        switch codecName {
        case "hdmv_pgs_subtitle": "sup"
        case "xsub": "xsub"
        default: "sub"
        }
    }

    enum CodingKeys: String, CodingKey {
        case channels
        case codecName = "codec_name"
        case codecTagString = "codec_tag_string"
        case codecType = "codec_type"
        case disposition
        case index
        case tags
    }

    private static let bitmapSubtitleCodecs: Set<String> = [
        "dvb_subtitle",
        "dvd_subtitle",
        "hdmv_pgs_subtitle",
        "xsub",
    ]
}

/// Probes media files for stream and container metadata.
public protocol MediaProbing: Sendable {
    /// Returns ffprobe metadata for `file`.
    func probe(_ file: URL) async throws -> MediaProbe
}

/// Probes media files with ffprobe to obtain their stream information.
public struct MediaProber: MediaProbing {
    private let runner: any CommandOutputCapturing

    /// Creates a prober.
    /// - Parameter runner: The command runner used to invoke ffprobe.
    public init(runner: any CommandOutputCapturing = ToolRunner()) {
        self.runner = runner
    }

    /// Probes a media file and returns its decoded stream information.
    ///
    /// Runs `ffprobe` as a subprocess to read the file's stream metadata as JSON
    /// and decodes it. Audio-only and subtitle-only files are valid probes;
    /// callers that require video should validate ``MediaProbe/firstVideoStream``.
    /// - Parameter file: The media file to probe.
    /// - Returns: The decoded ``MediaProbe`` describing the file's streams.
    /// - Throws: ``MediaProbeError/unreadableProbe(path:)`` if ffprobe's output
    ///   cannot be decoded, or an execution error if ffprobe exits unsuccessfully.
    public func probe(_ file: URL) async throws -> MediaProbe {
        let output = try await runner.captureOutput(
            of: "ffprobe",
            arguments: [
                "-v", "error",
                "-show_entries",
                "format=duration:stream=index,codec_name,codec_tag_string,codec_type,channels,disposition:stream_tags=language,title",
                "-of", "json",
                file.path,
            ],
        )

        guard let probe = try? JSONDecoder().decode(MediaProbe.self, from: Data(output.utf8)) else {
            throw MediaProbeError.unreadableProbe(path: file.path)
        }
        return probe
    }
}
