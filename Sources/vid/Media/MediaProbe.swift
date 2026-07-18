import Foundation

/// A decoded summary of the streams contained in a media file, as reported by
/// ffprobe.
struct MediaProbe: Decodable, Sendable {
    /// Container-level metadata reported for the media file.
    struct Format: Decodable, Sendable {
        /// Duration in seconds, represented by ffprobe as a decimal string.
        let duration: String?
    }

    /// All streams reported for the media file, in ffprobe's order.
    let streams: [MediaStream]
    /// Container-level metadata reported by ffprobe.
    let format: Format?

    /// Creates a probe from known streams and optional container metadata.
    init(streams: [MediaStream], format: Format? = nil) {
        self.streams = streams
        self.format = format
    }

    /// The audio streams contained in the media file.
    var audioStreams: [MediaStream] {
        streams.filter { $0.codecType == "audio" }
    }

    /// The subtitle streams encoded as bitmap subtitles.
    var bitmapSubtitleStreams: [MediaStream] {
        subtitleStreams.filter(\.isBitmapSubtitle)
    }

    /// Duration in seconds, when ffprobe supplied a finite positive value.
    var durationSeconds: Double? {
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
    var firstVideoStream: MediaStream? {
        streams.first { $0.codecType == "video" && $0.disposition?.attachedPicture != 1 }
    }

    /// The subtitle streams contained in the media file.
    var subtitleStreams: [MediaStream] {
        streams.filter { $0.codecType == "subtitle" }
    }

    /// The subtitle streams encoded as text.
    var textSubtitleStreams: [MediaStream] {
        subtitleStreams.filter { !$0.isBitmapSubtitle }
    }
}

/// A single stream within a media file, as decoded from ffprobe's JSON output.
struct MediaStream: Decodable, Sendable {
    /// The disposition flags describing a stream's role.
    struct Disposition: Decodable, Sendable {
        /// Whether the stream is an attached picture.
        let attachedPicture: Int?
        /// Whether the stream is the source's default track.
        let isDefault: Int?
        /// Whether the stream contains forced subtitles.
        let isForced: Int?
        /// Whether the stream serves deaf and hard-of-hearing viewers.
        let isHearingImpaired: Int?

        init(
            attachedPicture: Int? = nil,
            isDefault: Int? = nil,
            isForced: Int? = nil,
            isHearingImpaired: Int? = nil,
        ) {
            self.attachedPicture = attachedPicture
            self.isDefault = isDefault
            self.isForced = isForced
            self.isHearingImpaired = isHearingImpaired
        }

        enum CodingKeys: String, CodingKey {
            case attachedPicture = "attached_pic"
            case isDefault = "default"
            case isForced = "forced"
            case isHearingImpaired = "hearing_impaired"
        }
    }

    /// The metadata tags attached to a stream.
    struct Tags: Decodable, Sendable {
        /// The stream's language tag.
        let language: String?
        /// The stream's human-readable title.
        let title: String?

        init(language: String? = nil, title: String? = nil) {
            self.language = language
            self.title = title
        }
    }

    /// The stream's index within the media file.
    let index: Int
    /// The name of the codec used by the stream.
    let codecName: String?
    /// The MP4 codec tag reported for the stream.
    let codecTagString: String?
    /// The stream's media type.
    let codecType: String?
    /// The number of audio channels.
    let channels: Int?
    /// The stream's disposition flags.
    let disposition: Disposition?
    /// The stream's metadata tags.
    let tags: Tags?

    init(
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
    var isBitmapSubtitle: Bool {
        guard let codecName else {
            return false
        }
        return Self.bitmapSubtitleCodecs.contains(codecName)
    }

    /// The stream's language code, lowercased.
    var language: String? {
        tags?.language?.lowercased()
    }

    /// The file extension used when extracting this subtitle stream.
    var subtitleFileExtension: String {
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
                "format=duration:stream=index,codec_name,codec_tag_string,codec_type,channels,disposition:stream_tags=language,title",
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
