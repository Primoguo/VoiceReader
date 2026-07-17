// Knowledge/Services/SpeechSynthesizerProtocol.swift
import Foundation

/// 语音合成引擎抽象协议，方便单元测试 mock
protocol SpeechSynthesizerProtocol: AnyObject {
    var state: PlaybackState { get }
    /// 位置回调，携带 generation token 用于上层过滤旧回调
    var onPositionChange: ((Int, UInt64) -> Void)? { get set }
    /// 当前朗读的字符范围（全文绝对位置）
    var onRangeChange: ((NSRange) -> Void)? { get set }
    /// 引擎发生不可恢复错误时回调（用于上层降级）
    var onError: ((Error) -> Void)? { get set }
    /// 当前 speak 代次（每次 speak/stop 递增），用于上层检测旧回调
    var speakGeneration: UInt64 { get }

    func speak(text: String, from position: Int, config: VoiceConfig)
    func pause()
    func resume()
    func stop()
    func skipForward(by seconds: TimeInterval)
    func skipBackward(by seconds: TimeInterval)

    /// 更新朗读语速（不重启播放，立即生效）
    func updateRate(_ rate: Float)
}
