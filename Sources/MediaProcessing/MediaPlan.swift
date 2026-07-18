import FFprobe
import Foundation

/// An authored, user-intent description of a media operation that can be
/// compiled into a concrete FFmpeg execution plan.
///
/// A conforming type captures the intent of a command (remux, encode, repair,
/// or subtitle work) and knows how to translate a probed input into the FFmpeg
/// arguments and sidecar extractions required to produce the output.
public protocol MediaOperationPlan: Sendable {
    /// The suffix inserted into the output filename when the default `.mp4`
    /// name would collide with the input file (for example `subtitled` yields
    /// `movie.subtitled.mp4`).
    var outputFilenameSuffix: String { get }

    /// Builds the concrete FFmpeg execution plan for a single input file.
    ///
    /// - Parameters:
    ///   - input: The source media file to read from.
    ///   - output: The destination the FFmpeg invocation should write to,
    ///     typically a temporary URL owned by an ``OutputTransaction``.
    ///   - probe: The stream metadata previously gathered for `input`.
    /// - Returns: The FFmpeg arguments and any bitmap subtitle streams that must
    ///   be extracted to sidecar files.
    /// - Throws: An error when the probe lacks a stream the plan requires.
    func makeExecutionPlan(
        input: URL,
        output: URL,
        probe: MediaProbe,
    ) throws -> FFmpegExecutionPlan
}
