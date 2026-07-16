// KnowledgeWidgetLiveActivity.swift
// KnowledgeWidget — 录音 Live Activity UI（灵动岛 + 锁屏）
// 注意：RecordingActivityAttributes 定义在共享文件 Models/RecordingActivityAttributes.swift
import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Widget

struct KnowledgeWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            // === 锁屏横幅 UI ===
            lockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // === 灵动岛展开 UI ===
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                        .foregroundColor(.red)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("语音速记")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPaused {
                        Image(systemName: "pause.circle.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                    } else {
                        liveTimer(startDate: context.state.recordingStartDate)
                            .foregroundColor(.white)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isPaused {
                        Text("检测到静音，已暂停")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        liveTimer(startDate: context.state.recordingStartDate)
                            .font(.system(size: 28, weight: .light, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            } compactLeading: {
                Image(systemName: "mic.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            } compactTrailing: {
                if context.state.isPaused {
                    Image(systemName: "pause.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else {
                    liveTimer(startDate: context.state.recordingStartDate)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(.white)
                }
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "mic.fill")
                    .font(.caption)
                    .foregroundColor(context.state.isPaused ? .orange : .red)
            }
            .widgetURL(URL(string: "knowledge://recording"))
            .keylineTint(.red)
        }
    }

    // MARK: - 锁屏横幅视图

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<RecordingActivityAttributes>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: "mic.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("语音速记")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                if context.state.isPaused {
                    Text("已暂停")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            if context.state.isPaused {
                Image(systemName: "pause.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            } else {
                liveTimer(startDate: context.state.recordingStartDate)
                    .font(.system(size: 22, weight: .light, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 实时计时器

    private func liveTimer(startDate: Date) -> Text {
        Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
    }
}

// MARK: - Preview

extension RecordingActivityAttributes {
    fileprivate static var preview: RecordingActivityAttributes {
        RecordingActivityAttributes()
    }
}

extension RecordingActivityAttributes.ContentState {
    fileprivate static var recording: RecordingActivityAttributes.ContentState {
        RecordingActivityAttributes.ContentState(
            recordingStartDate: Date().addingTimeInterval(-125),
            isPaused: false
        )
    }

    fileprivate static var paused: RecordingActivityAttributes.ContentState {
        RecordingActivityAttributes.ContentState(
            recordingStartDate: Date().addingTimeInterval(-300),
            isPaused: true
        )
    }
}

#Preview("录音中", as: .content, using: RecordingActivityAttributes.preview) {
    KnowledgeWidgetLiveActivity()
} contentStates: {
    RecordingActivityAttributes.ContentState.recording
    RecordingActivityAttributes.ContentState.paused
}

#Preview("灵动岛", as: .dynamicIsland(.expanded), using: RecordingActivityAttributes.preview) {
    KnowledgeWidgetLiveActivity()
} contentStates: {
    RecordingActivityAttributes.ContentState.recording
    RecordingActivityAttributes.ContentState.paused
}
