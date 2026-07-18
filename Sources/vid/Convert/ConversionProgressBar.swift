import Foundation
import MediaConversion

/// Renders conversion progress events as terminal progress bars.
actor TerminalConversionProgressReporter {
    func report(_ progress: MediaConversionProgress) {
        let line: String
        let completesLine: Bool
        switch progress {
        case .file(let file, let fraction):
            line = "Converting \(ProgressBar.render(fraction: fraction)) \(file.lastPathComponent)"
            completesLine = fraction >= 1
        case .batch(let processed, let total):
            let fraction = total == 0 ? 1 : Double(processed) / Double(total)
            line = "Files      \(ProgressBar.render(fraction: fraction)) \(processed)/\(total)"
            completesLine = processed >= total
        }

        let terminator = completesLine ? "\n" : ""
        FileHandle.standardError.write(Data("\r\(line)\u{001B}[K\(terminator)".utf8))
    }
}

/// Produces a fixed-width textual progress bar and percentage.
enum ProgressBar {
    static func render(fraction: Double, width: Int = 30) -> String {
        let clamped = min(max(fraction, 0), 1)
        let filledWidth = Int((clamped * Double(width)).rounded(.down))
        let emptyWidth = width - filledWidth
        let percentage = Int((clamped * 100).rounded())
        return
            "[\(String(repeating: "=", count: filledWidth))\(String(repeating: "-", count: emptyWidth))] \(percentage)%"
    }
}
