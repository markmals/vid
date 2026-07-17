import Foundation

struct RepairPlan: MediaPlan {
    let operationName = "repaired"

    func makeProcessingPlan(
        input: URL,
        output: URL,
        probe: MediaProbe,
    ) throws -> MediaProcessingPlan {
        let video = try FFmpegPlanSupport.requireVideo(probe, input: input)
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

        return MediaProcessingPlan(
            ffmpegArguments: arguments,
            bitmapSubtitlesToExtract: [],
        )
    }
}
