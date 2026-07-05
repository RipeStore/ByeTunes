import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
final class DownloadLiveActivityManager {
    static let shared = DownloadLiveActivityManager()

    private init() {}

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "downloadLiveActivitiesEnabled") as? Bool ?? true
    }

    func update(
        trackName: String,
        artistName: String,
        progress: Double,
        queueText: String,
        speedBps: Double,
        phase: DownloadLiveActivityAttributes.Phase
    ) {
        guard #available(iOS 16.2, *) else { return }
        guard isEnabled else { return }
        DownloadLiveActivityRuntime.shared.update(
            trackName: trackName,
            artistName: artistName,
            progress: progress,
            queueText: queueText,
            speedBps: speedBps,
            phase: phase
        )
    }

    func end(
        trackName: String,
        artistName: String,
        queueText: String,
        phase: DownloadLiveActivityAttributes.Phase
    ) {
        guard #available(iOS 16.2, *) else { return }
        guard isEnabled else { return }
        DownloadLiveActivityRuntime.shared.end(
            trackName: trackName,
            artistName: artistName,
            queueText: queueText,
            phase: phase
        )
    }

    func clear() {
        guard #available(iOS 16.2, *) else { return }
        DownloadLiveActivityRuntime.shared.clear()
    }
}

#if canImport(ActivityKit)
@available(iOS 16.2, *)
@MainActor
private final class DownloadLiveActivityRuntime {
    static let shared = DownloadLiveActivityRuntime()

    private var currentActivity: Activity<DownloadLiveActivityAttributes>?
    private var pendingState: DownloadLiveActivityAttributes.ContentState?
    private var updateTask: Task<Void, Never>?
    private var lastState: DownloadLiveActivityAttributes.ContentState?
    private var lastUpdateAt: Date = .distantPast

    private init() {}

    func update(
        trackName: String,
        artistName: String,
        progress: Double,
        queueText: String,
        speedBps: Double,
        phase: DownloadLiveActivityAttributes.Phase
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = DownloadLiveActivityAttributes.ContentState(
            trackName: trackName,
            artistName: artistName,
            progress: max(0, min(progress, 1)),
            queueText: queueText,
            statusText: statusText(for: phase),
            speedText: formattedSpeed(speedBps),
            phase: phase
        )

        enqueueUpdate(state)
    }

    func end(
        trackName: String,
        artistName: String,
        queueText: String,
        phase: DownloadLiveActivityAttributes.Phase
    ) {
        let state = DownloadLiveActivityAttributes.ContentState(
            trackName: trackName,
            artistName: artistName,
            progress: (phase == .completed || phase == .allCompleted) ? 1 : 0,
            queueText: queueText,
            statusText: statusText(for: phase),
            speedText: formattedSpeed(0),
            phase: phase
        )

        Task {
            updateTask?.cancel()
            updateTask = nil
            pendingState = nil
            lastState = state
            let activity = currentActivity ?? Activity<DownloadLiveActivityAttributes>.activities.first
            currentActivity = nil
            guard let activity else { return }
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .after(.now + 15)
            )
        }
    }

    func clear() {
        Task {
            let activities = Activity<DownloadLiveActivityAttributes>.activities
            currentActivity = nil
            updateTask?.cancel()
            updateTask = nil
            pendingState = nil
            lastState = nil
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func enqueueUpdate(_ incomingState: DownloadLiveActivityAttributes.ContentState) {
        var state = incomingState
        if
            let lastState,
            lastState.trackName == state.trackName,
            lastState.artistName == state.artistName,
            lastState.phase == .downloading,
            state.phase == .preparing
        {
            state.progress = lastState.progress
            state.speedText = lastState.speedText
            state.statusText = statusText(for: .downloading)
            state.phase = .downloading
        }

        pendingState = state
        guard updateTask == nil else { return }

        updateTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                guard let state = self.pendingState else {
                    self.updateTask = nil
                    return
                }
                self.pendingState = nil

                if state.phase == .downloading {
                    let elapsed = Date().timeIntervalSince(self.lastUpdateAt)
                    if elapsed < 0.25 {
                        let delay = UInt64((0.25 - elapsed) * 1_000_000_000)
                        try? await Task.sleep(nanoseconds: delay)
                    }
                }

                guard !Task.isCancelled else { return }

                let latestState = self.pendingState ?? state
                if latestState != state {
                    self.pendingState = nil
                }

                await self.applyUpdate(latestState)
                self.lastState = latestState
                self.lastUpdateAt = Date()
            }
        }
    }

    private func applyUpdate(_ state: DownloadLiveActivityAttributes.ContentState) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(90))

        if let activity = currentActivity {
            await activity.update(content)
            return
        }

        if let existing = Activity<DownloadLiveActivityAttributes>.activities.first {
            currentActivity = existing
            await existing.update(content)
            return
        }

        do {
            currentActivity = try Activity.request(
                attributes: DownloadLiveActivityAttributes(title: "Download"),
                content: content,
                pushType: nil
            )
        } catch {
            Logger.shared.log("[DownloadLiveActivity] Failed to start live activity: \(error.localizedDescription)")
        }
    }

    private func statusText(for phase: DownloadLiveActivityAttributes.Phase) -> String {
        switch phase {
        case .preparing:
            return "Preparing download"
        case .downloading:
            return "Downloading"
        case .paused:
            return "Paused"
        case .completed:
            return "Download complete"
        case .allCompleted:
            return BackgroundMetadataFetchManager.isEnabled ? "Fetching metadata" : "Ready for metadata"
        case .failed:
            return "Download failed"
        case .cancelled:
            return "Download cancelled"
        }
    }

    private func formattedSpeed(_ bps: Double) -> String {
        guard bps > 0 else { return "0 KB/s" }
        let kb = bps / 1024
        if kb < 1024 {
            return String(format: "%.0f KB/s", kb)
        }
        return String(format: "%.2f MB/s", kb / 1024)
    }
}
#endif
