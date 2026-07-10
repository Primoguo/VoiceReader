// Knowledge/Services/HapticService.swift
import UIKit

/// 触觉反馈服务 — 统一管理 App 内所有 Haptic 反馈
/// 预初始化 generator 避免延迟，调用方一行代码即可触发
final class HapticService {
    static let shared = HapticService()

    // 预创建的 generator（减少首次触发延迟）
    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    private init() {
        // 预热 generator，首次触发更快
        impactSoft.prepare()
        impactLight.prepare()
        impactRigid.prepare()
        selection.prepare()
        notification.prepare()
    }

    // MARK: - 播放/暂停（soft impact）

    /// 播放或暂停时触发
    func playPause() {
        impactSoft.impactOccurred()
        impactSoft.prepare() // 为下次准备
    }

    // MARK: - 快进/快退（light impact）

    /// 快进或快退时触发
    func skip() {
        impactLight.impactOccurred()
        impactLight.prepare()
    }

    // MARK: - 拖拽进度条经过段落边界（selection）

    /// 拖拽进度条越过段落边界时触发
    func paragraphBoundary() {
        selection.selectionChanged()
        selection.prepare()
    }

    // MARK: - 切换语速（rigid impact）

    /// 切换语速档位时触发
    func speedChange() {
        impactRigid.impactOccurred()
        impactRigid.prepare()
    }

    // MARK: - 操作成功/失败（notification）

    func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    func error() {
        notification.notificationOccurred(.error)
        notification.prepare()
    }
}
