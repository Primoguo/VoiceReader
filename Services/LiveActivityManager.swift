// Knowledge/Services/LiveActivityManager.swift
import ActivityKit
import Foundation

/// 管理录音 Live Activity 的生命周期（启动、更新、结束）
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    private var currentActivity: Activity<RecordingActivityAttributes>?

    /// 当前是否有活跃的 Live Activity
    var isActive: Bool { currentActivity != nil }

    // MARK: - 启动 Live Activity（录音开始时调用）

    func startRecordingActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Live Activity 不可用")
            return
        }

        // 结束之前的（如果有残留）
        endActivity()

        let attributes = RecordingActivityAttributes()
        let initialState = RecordingActivityAttributes.ContentState(
            recordingStartDate: Date(),
            isPaused: false
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("[LiveActivity] Started: \(activity.id)")
        } catch {
            print("[LiveActivity] Failed to start: \(error.localizedDescription)")
        }
    }

    // MARK: - 更新状态（暂停/恢复时调用）

    func updatePaused(_ paused: Bool) {
        guard let activity = currentActivity else { return }

        let state = RecordingActivityAttributes.ContentState(
            recordingStartDate: activity.contentState.recordingStartDate,
            isPaused: paused
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
            print("[LiveActivity] Updated: paused=\(paused)")
        }
    }

    // MARK: - 结束 Live Activity（录音停止时调用）

    func endActivity() {
        guard let activity = currentActivity else { return }

        let finalState = RecordingActivityAttributes.ContentState(
            recordingStartDate: activity.contentState.recordingStartDate,
            isPaused: true
        )

        Task {
            // 结束后在锁屏保留 4 秒再消失
            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: .after(.now + 4)
            )
            print("[LiveActivity] Ended: \(activity.id)")
        }
        currentActivity = nil
    }
}
