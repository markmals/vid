import Foundation

/// A media operation plan that re-encodes the video to H.264 and the first
/// audio stream to AAC, deinterlacing the picture to repair a damaged source.
struct RepairPlan: MediaOperationPlan {
    /// The filename suffix (`repaired`) applied when the default output would
    /// collide with the source file.
    let outputFilenameSuffix = "repaired"

    /// Builds the FFmpeg execution plan that repairs the source file.
    ///
    /// Only the video and first audio stream are kept; the video is re-encoded
    /// with `libx264` and a `yadif` deinterlacing filter, the audio is encoded
    /// to AAC, and all subtitles are discarded.
    ///
    /// - Parameters:
    ///   - input: The source media file to repair.
    ///   - output: The destination file path written by FFmpeg.
    ///   - probe: The probe describing the source streams.
    /// - Returns: The execution plan with the FFmpeg arguments and no bitmap
    ///   subtitles to extract.
    /// - Throws: ``VidError/noVideoStream(path:)`` when `input` has no video stream.
    func makeExecutionPlan(
        input: URL,
        output: URL,
        probe: MediaProbe,
    ) throws -> FFmpegExecutionPlan {
        let video = try FFmpegPlanSupport.requiredVideoStream(in: probe, input: input)
        let firstAudio = Array(probe.audioStreams.prefix(1))

        var arguments = FFmpegPlanSupport.inputArguments(input)
        FFmpegPlanSupport.appendMaps(
            video: video,
            audio: firstAudio,
            subtitles: [],
            to: &arguments,
        )
        arguments += [
            "-c:v", "libx264",
            "-crf", "18",
            "-preset", "medium",
            "-vf", "yadif,format=yuv420p",
            "-c:a", "aac",
            "-b:a", "192k",
            "-sn",
            "-movflags", "+faststart",
            output.path,
        ]

        return FFmpegExecutionPlan(
            ffmpegArguments: arguments,
            subtitleExtractions: []
        )
    }
}
