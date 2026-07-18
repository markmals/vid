import FFprobe
import Foundation
import MediaProcessing

/// The single text subtitle selected for MP4 embedding.
enum SelectedConversionSubtitle: Sendable {
    case embedded(MediaStream)
    case external(ExternalSubtitle)
}

/// Chooses one subtitle for embedding and plans every required sidecar output.
struct ConversionSubtitleSelection: Sendable {
    let selected: SelectedConversionSubtitle?
    let extractions: [SubtitleExtractionPlan]

    init(
        input: URL,
        probe: MediaProbe,
        externalSubtitles: [ExternalSubtitle]
    ) {
        let embeddedCandidates = probe.textSubtitleStreams.map { stream in
            Candidate(source: .embedded(stream), role: Self.role(for: stream))
        }
        let externalCandidates = externalSubtitles.map { subtitle in
            Candidate(source: .external(subtitle), role: subtitle.role)
        }
        let candidates = embeddedCandidates + externalCandidates
        let selectedCandidate = candidates.enumerated().min { lhs, rhs in
            if lhs.element.role == rhs.element.role {
                return lhs.offset < rhs.offset
            }
            return lhs.element.role < rhs.element.role
        }?.element
        selected = selectedCandidate?.source.selectedSubtitle
        extractions = Self.extractions(
            input: input,
            probe: probe,
            externalSubtitles: externalSubtitles,
            selected: selectedCandidate?.source
        )
    }

    private static func extractions(
        input: URL,
        probe: MediaProbe,
        externalSubtitles: [ExternalSubtitle],
        selected: Candidate.Source?
    ) -> [SubtitleExtractionPlan] {
        let baseName = input.deletingPathExtension().lastPathComponent
        let selectedEmbeddedIndex = selected?.embeddedStream?.index
        let selectedExternalURL = selected?.externalSubtitle?.url.standardizedFileURL
        var usedFilenames = Set<String>()
        var plans: [SubtitleExtractionPlan] = []

        for stream in probe.textSubtitleStreams where stream.index != selectedEmbeddedIndex {
            let descriptor = textDescriptor(for: stream)
            let filename = uniqueFilename(
                "\(baseName).\(descriptor).srt",
                streamIndex: stream.index,
                usedFilenames: &usedFilenames
            )
            plans.append(
                SubtitleExtractionPlan(
                    inputURL: input,
                    stream: stream,
                    outputFilename: filename,
                    encoding: .srt
                ))
        }

        for stream in probe.bitmapSubtitleStreams {
            let descriptor = bitmapDescriptor(for: stream)
            let filename = uniqueFilename(
                "\(baseName).\(descriptor).\(stream.subtitleFileExtension)",
                streamIndex: stream.index,
                usedFilenames: &usedFilenames
            )
            plans.append(
                SubtitleExtractionPlan(
                    inputURL: input,
                    stream: stream,
                    outputFilename: filename,
                    encoding: .copy
                ))
        }

        let existingSRTFilenames = Set(
            externalSubtitles
                .filter { $0.url.pathExtension.lowercased() == "srt" }
                .map { $0.url.lastPathComponent.lowercased() }
        )
        for subtitle in externalSubtitles
        where subtitle.url.standardizedFileURL != selectedExternalURL
            && subtitle.url.pathExtension.lowercased() != "srt"
        {
            let filename = "\(subtitle.url.deletingPathExtension().lastPathComponent).srt"
            guard !existingSRTFilenames.contains(filename.lowercased()) else {
                continue
            }
            let uniqueName = uniqueFilename(
                filename,
                streamIndex: 0,
                usedFilenames: &usedFilenames
            )
            let stream = MediaStream(
                index: 0,
                codecName: subtitle.url.pathExtension.lowercased(),
                codecType: "subtitle",
                disposition: nil,
                tags: MediaStream.Tags(language: subtitle.language)
            )
            plans.append(
                SubtitleExtractionPlan(
                    inputURL: subtitle.url,
                    stream: stream,
                    outputFilename: uniqueName,
                    encoding: .srt
                ))
        }
        return plans
    }

    private static func role(for stream: MediaStream) -> ConversionSubtitleRole {
        if stream.disposition?.forcedFlag == 1 {
            return .forced
        }
        if stream.disposition?.defaultFlag == 1 {
            return .defaultTrack
        }
        if stream.disposition?.hearingImpairedFlag == 1 || titleMarksSDH(stream.tags?.title) {
            return .sdh
        }
        return .unspecified
    }

    private static func titleMarksSDH(_ title: String?) -> Bool {
        guard let title else {
            return false
        }
        let words = Set(
            title.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        )
        return words.contains("sdh") || words.contains("cc")
    }

    private static func textDescriptor(for stream: MediaStream) -> String {
        let language = sanitized(stream.language)
        let roleName: String?
        switch role(for: stream) {
        case .forced: roleName = "forced"
        case .defaultTrack: roleName = "default"
        case .sdh: roleName = "sdh"
        case .unspecified: roleName = nil
        }
        return [language, roleName].compactMap { $0 }.joined(separator: ".").nilIfEmpty
            ?? "sub\(stream.index)"
    }

    private static func bitmapDescriptor(for stream: MediaStream) -> String {
        let codec: String
        switch stream.codecName {
        case "dvb_subtitle": codec = "dvbsub"
        case "dvd_subtitle": codec = "dvdsub"
        case "hdmv_pgs_subtitle": codec = "pgssub"
        case "xsub": codec = "xsub"
        default: codec = "sub\(stream.index)"
        }
        return [sanitized(stream.language), codec].compactMap { $0 }.joined(separator: ".")
    }

    private static func sanitized(_ component: String?) -> String? {
        guard let component else {
            return nil
        }
        let sanitized = component.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return sanitized.isEmpty ? nil : sanitized
    }

    private static func uniqueFilename(
        _ filename: String,
        streamIndex: Int,
        usedFilenames: inout Set<String>
    ) -> String {
        guard !usedFilenames.contains(filename.lowercased()) else {
            let url = URL(fileURLWithPath: filename)
            let alternate =
                "\(url.deletingPathExtension().lastPathComponent).sub\(streamIndex).\(url.pathExtension)"
            usedFilenames.insert(alternate.lowercased())
            return alternate
        }
        usedFilenames.insert(filename.lowercased())
        return filename
    }
}

private struct Candidate: Sendable {
    enum Source: Sendable {
        case embedded(MediaStream)
        case external(ExternalSubtitle)

        var embeddedStream: MediaStream? {
            guard case .embedded(let stream) = self else { return nil }
            return stream
        }

        var externalSubtitle: ExternalSubtitle? {
            guard case .external(let subtitle) = self else { return nil }
            return subtitle
        }

        var selectedSubtitle: SelectedConversionSubtitle {
            switch self {
            case .embedded(let stream): .embedded(stream)
            case .external(let subtitle): .external(subtitle)
            }
        }
    }

    let source: Source
    let role: ConversionSubtitleRole
}

extension String {
    fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}
