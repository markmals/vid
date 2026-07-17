import Foundation

enum FFmpegPlanSupport {
    static func inputArguments(_ input: URL) -> [String] {
        [
            "-hide_banner", "-nostdin", "-y",
            "-probesize", "50M",
            "-analyzeduration", "50M",
            "-i", input.path,
        ]
    }

    static func requireVideo(_ probe: MediaProbe, input: URL) throws -> MediaStream {
        guard let video = probe.firstVideoStream else {
            throw VidError.noVideoStream(input.path)
        }
        return video
    }

    static func subtitleStreams(
        in probe: MediaProbe,
        handling: SubtitleHandling,
    ) -> [MediaStream] {
        switch handling {
        case .extractBitmap, .textOnly:
            probe.textSubtitleStreams
        case .none:
            []
        }
    }

    static func bitmapSubtitles(
        in probe: MediaProbe,
        handling: SubtitleHandling,
    ) -> [MediaStream] {
        switch handling {
        case .extractBitmap:
            probe.bitmapSubtitleStreams
        case .none, .textOnly:
            []
        }
    }

    static func appendMaps(
        video: MediaStream,
        audio: [MediaStream],
        subtitles: [MediaStream],
        to arguments: inout [String],
    ) {
        arguments += ["-map", "0:\(video.index)"]
        for stream in audio {
            arguments += ["-map", "0:\(stream.index)?"]
        }
        for stream in subtitles {
            arguments += ["-map", "0:\(stream.index)?"]
        }
    }

    static func appendAudioEncoding(
        _ encoding: AudioEncoding,
        to arguments: inout [String],
    ) {
        switch encoding {
        case .aac(let bitrate):
            arguments += ["-c:a", "aac", "-b:a", bitrate]
        case .copy:
            arguments += ["-c:a", "copy"]
        case .eac3(let bitrate):
            arguments += ["-c:a", "eac3", "-b:a", bitrate]
        }
    }

    static func appendAudioTags(
        sourceStreams: [MediaStream],
        encoding: AudioEncoding,
        to arguments: inout [String],
    ) {
        for (outputIndex, stream) in sourceStreams.enumerated() {
            let tag: String?
            switch encoding {
            case .eac3:
                tag = "ec-3"
            case .copy:
                switch stream.codecName {
                case "ac3": tag = "ac-3"
                case "eac3": tag = "ec-3"
                default: tag = nil
                }
            case .aac:
                tag = nil
            }

            if let tag {
                arguments += ["-tag:a:\(outputIndex)", tag]
            }
        }
    }

    static func appendTextSubtitleCodec(
        when streams: [MediaStream],
        to arguments: inout [String],
    ) {
        if streams.isEmpty {
            arguments += ["-sn"]
        } else {
            arguments += ["-c:s", "mov_text"]
        }
    }
}
