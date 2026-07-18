import Foundation

/// A subtitle track's role when choosing the single track embedded in an MP4.
public enum ConversionSubtitleRole: Int, Comparable, Sendable {
    /// Dialogue required to understand otherwise untranslated speech.
    case forced
    /// The source's preferred default subtitle track.
    case defaultTrack
    /// Subtitles for deaf and hard-of-hearing viewers.
    case sdh
    /// A subtitle without a preferred role.
    case unspecified

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A text subtitle file stored beside a video.
public struct ExternalSubtitle: Equatable, Sendable {
    /// The subtitle file URL.
    public let url: URL
    /// The language inferred from the filename, when present.
    public let language: String?
    /// The role inferred from the filename.
    public let role: ConversionSubtitleRole

    /// Creates external subtitle metadata.
    public init(url: URL, language: String?, role: ConversionSubtitleRole) {
        self.url = url
        self.language = language
        self.role = role
    }
}

/// Finds supported subtitle files whose basename matches a video.
public struct ExternalSubtitleDiscovery: Sendable {
    /// Creates an external subtitle discovery service.
    public init() {}

    /// Finds matching text subtitle sidecars in the video's directory.
    public func subtitles(matching video: URL) throws -> [ExternalSubtitle] {
        let directory = video.deletingLastPathComponent()
        let videoBaseName = video.deletingPathExtension().lastPathComponent
        let normalizedBaseName = videoBaseName.lowercased()
        let candidates = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return try candidates.compactMap { candidate in
            let values = try candidate.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true,
                Self.supportedExtensions.contains(candidate.pathExtension.lowercased())
            else {
                return nil
            }

            let candidateBaseName = candidate.deletingPathExtension().lastPathComponent
            let normalizedCandidateBaseName = candidateBaseName.lowercased()
            guard
                normalizedCandidateBaseName == normalizedBaseName
                    || normalizedCandidateBaseName.hasPrefix("\(normalizedBaseName).")
            else {
                return nil
            }

            let qualifiers = Self.qualifiers(
                candidateBaseName: normalizedCandidateBaseName,
                videoBaseName: normalizedBaseName
            )
            return ExternalSubtitle(
                url: candidate.standardizedFileURL,
                language: Self.language(in: qualifiers),
                role: Self.role(in: qualifiers)
            )
        }.sorted {
            $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending
        }
    }

    private static func qualifiers(
        candidateBaseName: String,
        videoBaseName: String
    ) -> [Substring] {
        guard candidateBaseName.count > videoBaseName.count else {
            return []
        }
        return candidateBaseName.dropFirst(videoBaseName.count + 1).split(separator: ".")
    }

    private static func language(in qualifiers: [Substring]) -> String? {
        qualifiers.lazy
            .map(String.init)
            .first { qualifier in
                (2...3).contains(qualifier.count)
                    && qualifier.allSatisfy(\.isLetter)
                    && !roleMarkers.contains(qualifier)
            }
    }

    private static func role(in qualifiers: [Substring]) -> ConversionSubtitleRole {
        let markers = Set(qualifiers.map(String.init))
        if markers.contains("forced") || markers.contains("foreign") {
            return .forced
        }
        if markers.contains("default") {
            return .defaultTrack
        }
        if !markers.isDisjoint(with: ["sdh", "cc", "hi", "hearing-impaired"]) {
            return .sdh
        }
        return .unspecified
    }

    private static let roleMarkers: Set<String> = [
        "cc", "default", "forced", "foreign", "hearing-impaired", "hi", "sdh",
    ]
    private static let supportedExtensions: Set<String> = [
        "srt", "sub", "ttxt", "txt", "vtt",
    ]
}
