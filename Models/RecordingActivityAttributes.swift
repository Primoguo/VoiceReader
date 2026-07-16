// Knowledge/Models/RecordingActivityAttributes.swift
// 共享数据模型 — 需同时属于 Knowledge（主 App）和 KnowledgeWidget（Widget Extension）两个 Target
import Foundation
import ActivityKit

/// 录音 Live Activity 属性
struct RecordingActivityAttributes: ActivityAttributes {
    /// 动态状态（可实时更新）
    public struct ContentState: Codable, Hashable {
        var recordingStartDate: Date     // 录音开始时间（用于 timerInterval）
        var isPaused: Bool               // 是否已暂停（静音检测触发）
    }
    // 固定属性（创建时设定，不可变）
    var activityType: String

    init(activityType: String = "recording") {
        self.activityType = activityType
    }
}
