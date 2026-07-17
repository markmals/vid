import Foundation

protocol MediaPlan: Sendable {
    var operationName: String { get }

    func makeProcessingPlan(
        input: URL,
        output: URL,
        probe: MediaProbe,
    ) throws -> MediaProcessingPlan
}
