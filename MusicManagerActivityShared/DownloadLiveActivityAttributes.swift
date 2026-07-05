import Foundation

#if canImport(ActivityKit)
import ActivityKit

struct DownloadLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var trackName: String
        var artistName: String
        var progress: Double
        var queueText: String
        var statusText: String
        var speedText: String
        var phase: Phase
    }

    enum Phase: String, Codable, Hashable {
        case preparing
        case downloading
        case paused
        case completed
        case allCompleted
        case failed
        case cancelled
    }

    var title: String
}
#endif
