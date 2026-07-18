import Foundation

@testable import vid

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("vid-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

@discardableResult
func writeTestFile(_ url: URL, contents: String = "test") throws -> URL {
    try Data(contents.utf8).write(to: url)
    return url
}

func mediaStream(
    index: Int,
    codec: String?,
    type: String?,
    language: String? = nil,
    attachedPicture: Int? = nil,
) -> MediaStream {
    MediaStream(
        index: index,
        codecName: codec,
        codecType: type,
        disposition: attachedPicture.map(MediaStream.Disposition.init(attachedPicture:)),
        tags: language.map(MediaStream.Tags.init(language:)),
    )
}

func mediaProbe(
    videoCodec: String = "h264",
    audioCodec: String = "aac",
    includeTextSubtitle: Bool = true,
    includeBitmapSubtitle: Bool = false,
) -> MediaProbe {
    var streams = [
        mediaStream(index: 0, codec: videoCodec, type: "video"),
        mediaStream(index: 1, codec: audioCodec, type: "audio", language: "eng"),
    ]
    if includeTextSubtitle {
        streams.append(mediaStream(index: 2, codec: "subrip", type: "subtitle", language: "eng"))
    }
    if includeBitmapSubtitle {
        streams.append(
            mediaStream(index: 3, codec: "hdmv_pgs_subtitle", type: "subtitle", language: "eng"))
    }
    return MediaProbe(streams: streams)
}

func outputPolicy(
    directory: URL? = nil,
    overwrite: Bool = false,
    removeSource: Bool = false,
    replaceInput: Bool = false,
) -> OutputPolicy {
    OutputPolicy(
        outputDirectory: directory,
        shouldOverwriteExistingOutput: overwrite,
        shouldRemoveSource: removeSource,
        shouldReplaceInput: replaceInput,
    )
}

@discardableResult
func makeExecutable(in directory: URL, name: String, script: String) throws -> URL {
    let executable = directory.appendingPathComponent(name)
    try "#!/bin/sh\nset -eu\n\(script)\n".write(
        to: executable,
        atomically: true,
        encoding: .utf8,
    )
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: executable.path,
    )
    return executable
}

func installFakeMediaTools(in directory: URL) throws -> URL {
    let tools = directory.appendingPathComponent("tools")
    try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)

    try makeExecutable(
        in: tools,
        name: "ffprobe",
        script: """
            printf '%s\\n' '{"streams":[{"index":0,"codec_name":"hevc","codec_type":"video","disposition":{"attached_pic":0}},{"index":1,"codec_name":"eac3","codec_type":"audio","tags":{"language":"ENG"}},{"index":2,"codec_name":"subrip","codec_type":"subtitle","tags":{"language":"eng"}},{"index":3,"codec_name":"hdmv_pgs_subtitle","codec_type":"subtitle","tags":{"language":"eng"}}]}'
            """,
    )
    try makeExecutable(
        in: tools,
        name: "ffmpeg",
        script: """
            output=''
            for argument do
                output="$argument"
            done
            printf 'media output' > "$output"
            """,
    )
    return tools
}

func withPrependedPath<T>(
    _ directory: URL,
    operation: () async throws -> T,
) async throws -> T {
    let previousPath = getenv("PATH").map { String(cString: $0) }
    let path = [directory.path, previousPath].compactMap { $0 }.joined(separator: ":")
    setenv("PATH", path, 1)
    defer {
        if let previousPath {
            setenv("PATH", previousPath, 1)
        } else {
            unsetenv("PATH")
        }
    }
    return try await operation()
}
