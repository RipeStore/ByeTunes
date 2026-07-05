import SwiftUI
import WidgetKit
import ActivityKit

private struct DownloadLiveActivityView: View {
    let state: DownloadLiveActivityAttributes.ContentState

    var body: some View {
        DownloadActivityCard(state: state, isCompact: false)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
}

private struct DownloadActivityCard: View {
    let state: DownloadLiveActivityAttributes.ContentState
    let isCompact: Bool

    private var percentText: String {
        "\(Int((state.progress * 100).rounded()))%"
    }

    private var accent: Color {
        switch state.phase {
        case .completed, .allCompleted:
            return .green
        case .failed, .cancelled:
            return .red
        case .paused:
            return .orange
        default:
            return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 7 : 9) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.trackName)
                        .font(isCompact ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(state.artistName)
                        .font(isCompact ? .caption : .subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 5) {
                        if state.phase == .completed || state.phase == .allCompleted {
                            Image(systemName: state.phase == .allCompleted ? "sparkles" : "checkmark.circle.fill")
                                .foregroundStyle(accent)
                                .scaleEffect(state.phase == .allCompleted ? 1.14 : 1.08)
                                .animation(.spring(response: 0.35, dampingFraction: 0.55), value: state.phase)
                        }
                        Text(state.queueText)
                            .font(isCompact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    Text(state.speedText)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: state.progress)
                .tint(accent)

            HStack(spacing: 8) {
                Text(state.statusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 8)
                Text(percentText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DownloadIslandBottomView: View {
    let state: DownloadLiveActivityAttributes.ContentState

    private var percentText: String {
        "\(Int((state.progress * 100).rounded()))%"
    }

    private var accent: Color {
        switch state.phase {
        case .completed, .allCompleted:
            return .green
        case .failed, .cancelled:
            return .red
        case .paused:
            return .orange
        default:
            return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ProgressView(value: state.progress)
                .tint(accent)
                .controlSize(.mini)

            HStack(spacing: 8) {
                Text(state.statusText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 6)

                Text(percentText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct DownloadLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadLiveActivityAttributes.self) { context in
            DownloadLiveActivityView(state: context.state)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(context.state.trackName)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        Text(context.state.artistName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                    .padding(.leading, 12)
                    .frame(maxWidth: 145, alignment: .leading)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(Int((context.state.progress * 100).rounded()))%")
                            .font(.caption2.weight(.semibold).monospacedDigit())
                        Text(context.state.queueText)
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(context.state.speedText)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.trailing, 12)
                    .frame(maxWidth: 70, alignment: .trailing)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    DownloadIslandBottomView(state: context.state)
                        .padding(.horizontal, 12)
                }
            } compactLeading: {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle((context.state.phase == .completed || context.state.phase == .allCompleted) ? .green : .blue)
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle((context.state.phase == .completed || context.state.phase == .allCompleted) ? .green : .blue)
            }
            .widgetURL(URL(string: "byetunes://download"))
            .keylineTint((context.state.phase == .completed || context.state.phase == .allCompleted) ? .green : .blue)
        }
    }
}

@main
struct MusicManagerLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        DownloadLiveActivityWidget()
    }
}
