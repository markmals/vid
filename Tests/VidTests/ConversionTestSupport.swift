import Foundation
import Testing

@testable import FFprobe
@testable import MediaConversion

struct ProbeStreamFixture {
    let index: Int
    let codec: String
    let type: String
    var codecTag: String?
    var channels: Int?
    var language: String?
    var title: String?
    var isDefault = false
    var isForced = false
    var isHearingImpaired = false
}

func conversionProbe(
    streams: [ProbeStreamFixture],
    duration: Double = 10,
) throws -> MediaProbe {
    let streamObjects: [[String: Any]] = streams.map { stream in
        var object: [String: Any] = [
            "index": stream.index,
            "codec_name": stream.codec,
            "codec_type": stream.type,
        ]
        if let codecTag = stream.codecTag {
            object["codec_tag_string"] = codecTag
        }
        if let channels = stream.channels {
            object["channels"] = channels
        }

        object["disposition"] = [
            "attached_pic": 0,
            "default": stream.isDefault ? 1 : 0,
            "forced": stream.isForced ? 1 : 0,
            "hearing_impaired": stream.isHearingImpaired ? 1 : 0,
        ]

        var tags: [String: Any] = [:]
        if let language = stream.language {
            tags["language"] = language
        }
        if let title = stream.title {
            tags["title"] = title
        }
        if !tags.isEmpty {
            object["tags"] = tags
        }
        return object
    }
    let data = try JSONSerialization.data(
        withJSONObject: [
            "streams": streamObjects,
            "format": ["duration": String(duration)],
        ]
    )
    return try JSONDecoder().decode(MediaProbe.self, from: data)
}

func conversionSettings(_ codec: ConversionVideoCodec) -> MediaConversionSettings {
    .makeHighQuality(videoCodec: codec)
}

actor ConversionProgressRecorder {
    private var events: [MediaConversionProgress] = []

    func record(_ event: MediaConversionProgress) {
        events.append(event)
    }

    func recordedEvents() -> [MediaConversionProgress] {
        events
    }
}
