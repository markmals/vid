import Foundation

/// A namespace of stateless helpers that assemble FFmpeg argument arrays and
/// select media streams shared by the media operation plans.
///
/// The type is an uninstantiable `enum` used purely to group these building
/// blocks so that every plan produces consistent maps, codec options, and tags.
enum FFmpegPlanSupport {
    /// Builds the standard leading FFmpeg arguments for reading a source file.
    ///
    /// The returned arguments suppress the banner and stdin, force overwriting
    /// of any existing output, widen the probe and analysis windows, and open
    /// the input file.
    ///
    /// - Parameter input: The source media file to read.
    /// - Returns: The ordered FFmpeg arguments that open `input`.
    static func inputArguments(_ input: URL) -> [String] {
        [
            "-hide_banner", "-nostdin", "-y",
            "-probesize", "50M",
            "-analyzeduration", "50M",
            "-i", input.path,
        ]
    }

    /// Returns the first video stream that the probe found in the source file.
    ///
    /// - Parameters:
    ///   - probe: The probe whose streams are searched for a video track.
    ///   - input: The source file whose path is reported if no video is found.
    /// - Returns: The first video stream in `probe`.
    /// - Throws: ``VidError/noVideoStream(path:)`` when `probe` contains no
    ///   video stream.
    static func requiredVideoStream(in probe: MediaProbe, input: URL) throws -> MediaStream {
        guard let video = probe.firstVideoStream else {
            throw VidError.noVideoStream(path: input.path)
        }
        return video
    }

    /// Returns the text subtitle streams to keep for the given handling mode.
    ///
    /// - Parameters:
    ///   - probe: The probe supplying the source subtitle streams.
    ///   - handling: The subtitle handling mode selecting which streams to keep.
    /// - Returns: The text subtitle streams for `.extractBitmap` and `.textOnly`
    ///   handling, or an empty array for `.none`.
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

    /// Returns the bitmap subtitle streams that must be extracted to sidecar files.
    ///
    /// - Parameters:
    ///   - probe: The probe supplying the source subtitle streams.
    ///   - handling: The subtitle handling mode selecting which streams to extract.
    /// - Returns: The bitmap subtitle streams for `.extractBitmap` handling, or
    ///   an empty array for `.none` and `.textOnly`.
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

    /// Appends the `-map` selectors for the chosen streams to the arguments.
    ///
    /// The video stream is mapped as required, while each audio and subtitle
    /// stream is mapped optionally so its absence does not fail the command.
    ///
    /// - Parameters:
    ///   - video: The video stream mapped as a required output.
    ///   - audio: The audio streams mapped as optional outputs.
    ///   - subtitles: The subtitle streams mapped as optional outputs.
    ///   - arguments: The FFmpeg arguments to append the map options to.
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

    /// Appends the audio codec and bitrate options for the given encoding.
    ///
    /// - Parameters:
    ///   - encoding: The audio encoding selecting the codec and bitrate, or
    ///     stream copying.
    ///   - arguments: The FFmpeg arguments to append the audio options to.
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

    /// Appends the Apple-compatible codec tags for each output audio stream.
    ///
    /// E-AC-3 encoding always tags its outputs `ec-3`; stream copying tags AC-3
    /// and E-AC-3 sources as `ac-3` and `ec-3` respectively; AAC encoding and
    /// other copied codecs receive no tag.
    ///
    /// - Parameters:
    ///   - sourceStreams: The source audio streams whose output order and codecs
    ///     determine the emitted tags.
    ///   - encoding: The audio encoding that, with the source codec, selects each tag.
    ///   - arguments: The FFmpeg arguments to append the tag options to.
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

    /// Appends the complete subtitle-output options for the given streams.
    ///
    /// When `streams` is empty the helper disables subtitle output with `-sn`;
    /// otherwise it selects the `mov_text` codec so the subtitles are written to
    /// the MP4 container.
    ///
    /// - Parameters:
    ///   - streams: The subtitle streams being written, or an empty array to
    ///     disable subtitle output.
    ///   - arguments: The FFmpeg arguments to append the subtitle options to.
    static func appendSubtitleOutputOptions(
        for streams: [MediaStream],
        to arguments: inout [String],
    ) {
        if streams.isEmpty {
            arguments += ["-sn"]
        } else {
            arguments += ["-c:s", "mov_text"]
        }
    }
}
