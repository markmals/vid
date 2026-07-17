import Foundation

struct MediaProbe: Decodable, Sendable {
    let streams: [MediaStream]

    var audioStreams: [MediaStream] {
        streams.filter { $0.codecType == "audio" }
    }

    var bitmapSubtitleStreams: [MediaStream] {
        subtitleStreams.filter(\.isBitmapSubtitle)
    }

    var firstVideoStream: MediaStream? {
        streams.first { $0.codecType == "video" && $0.disposition?.attachedPicture != 1 }
    }

    var subtitleStreams: [MediaStream] {
        streams.filter { $0.codecType == "subtitle" }
    }

    var textSubtitleStreams: [MediaStream] {
        subtitleStreams.filter { !$0.isBitmapSubtitle }
    }
}

struct MediaStream: Decodable, Sendable {
    struct Disposition: Decodable, Sendable {
        let attachedPicture: Int?

        enum CodingKeys: String, CodingKey {
            case attachedPicture = "attached_pic"
        }
    }

    struct Tags: Decodable, Sendable {
        let language: String?
    }

    let index: Int
    let codecName: String?
    let codecType: String?
    let disposition: Disposition?
    let tags: Tags?

    var isBitmapSubtitle: Bool {
        guard let codecName else {
            return false
        }

        return Self.bitmapSubtitleCodecs.contains(codecName)
    }

    var language: String? {
        tags?.language?.lowercased()
    }

    var subtitleFileExtension: String {
        switch codecName {
        case "hdmv_pgs_subtitle": "sup"
        case "xsub": "xsub"
        default: "sub"
        }
    }

    enum CodingKeys: String, CodingKey {
        case codecName = "codec_name"
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

struct MediaProber: Sendable {
    let runner: ToolRunner

    init(runner: ToolRunner = ToolRunner()) {
        self.runner = runner
    }

    func probe(_ file: URL) async throws -> MediaProbe {
        let output = try await runner.capture(
            "ffprobe",
            arguments: [
                "-v", "error",
                "-show_entries",
                "stream=index,codec_name,codec_type,disposition:stream_tags=language",
                "-of", "json",
                file.path,
            ],
        )

        guard let probe = try? JSONDecoder().decode(MediaProbe.self, from: Data(output.utf8)) else {
            throw VidError.unreadableProbe(file.path)
        }
        guard probe.firstVideoStream != nil else {
            throw VidError.noVideoStream(file.path)
        }

        return probe
    }
}
