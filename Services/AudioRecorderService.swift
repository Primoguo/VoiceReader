// Knowledge/Services/AudioRecorderService.swift
import AVFoundation
import Combine

/// 录音服务 — AVAudioRecorder 封装
/// 录制 16kHz 单声道 WAV，供 STT 识别
/// 内置安全机制：静音 30s 自动暂停、单次上限 2 小时
@MainActor
final class AudioRecorderService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var duration: TimeInterval = 0       // 已录制时长（秒）
    @Published var meterLevel: Float = 0            // 音量电平 0~1
    @Published var autoStopReason: AutoStopReason?  // 自动停止原因（视图监听）

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var startTime: Date?

    // MARK: - 安全机制配置

    /// 静音阈值（meterLevel 低于此值视为静音）
    private let silenceThreshold: Float = 0.05
    /// 静音自动暂停时间（秒）
    private let silenceAutoStopDuration: TimeInterval = 60
    /// 单次录音最大时长（秒）：2 小时
    static let maxRecordingDuration: TimeInterval = 2 * 3600

    /// 静音开始时间
    private var silenceStartTime: Date?

    // MARK: - 自动停止原因

    enum AutoStopReason: String {
        case silence = "检测到 60 秒静音，已自动暂停"
        case maxDuration = "已达到单次录音上限（2 小时），已自动停止"
    }

    /// 录音文件保存目录
    static var recordingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("vnote_recordings")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 当前录音文件 URL
    private(set) var currentFileURL: URL?

    // MARK: - 开始录音

    func startRecording() async throws {
        guard !isRecording else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)

        // 请求麦克风权限
        let granted = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        guard granted else {
            throw AudioRecorderError.microphonePermissionDenied
        }

        let fileName = "vnote_\(UUID().uuidString).wav"
        let fileURL = Self.recordingsDirectory.appendingPathComponent(fileName)
        currentFileURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.delegate = self
        let didStart = recorder?.record() ?? false
        if !didStart {
            print("[Recorder] WARNING: recorder.record() returned false")
        }

        isRecording = true
        autoStopReason = nil
        startTime = Date()
        duration = 0
        silenceStartTime = nil

        // 定时器：更新时长 + 音量 + 安全检查（必须在主线程 RunLoop 中调度）
        let t = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording else { return }
            if let start = self.startTime {
                self.duration = Date().timeIntervalSince(start)
            }
            if let recorder = self.recorder {
                recorder.updateMeters()
                let power = recorder.averagePower(forChannel: 0)
                // 将 dB (-160~0) 映射到 0~1
                self.meterLevel = max(0, min(1, (power + 50) / 50))
            }
            self.checkAutoStopConditions()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        print("[Recorder] Started: \(fileName), recorder.isRecording=\(recorder?.isRecording ?? false)")

        // 启动 Live Activity（灵动岛 + 锁屏显示录音状态）
        LiveActivityManager.shared.startRecordingActivity()
    }

    // MARK: - 停止录音

    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        recorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        meterLevel = 0

        let url = currentFileURL
        currentFileURL = nil

        // 切回播放模式
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.allowBluetoothHFP, .allowAirPlay])

        print("[Recorder] Stopped: \(url?.lastPathComponent ?? "nil"), duration: \(String(format: "%.1f", duration))s")

        // 结束 Live Activity
        LiveActivityManager.shared.endActivity()

        return url
    }

    // MARK: - 取消录音

    func cancelRecording() {
        let url = stopRecording()
        if let url = url {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Private: 自动停止检测

    private func checkAutoStopConditions() {
        // 1. 最大时长限制
        if duration >= Self.maxRecordingDuration {
            autoStopReason = .maxDuration
            _ = stopRecording()
            return
        }

        // 2. 静音检测
        if meterLevel < silenceThreshold {
            if silenceStartTime == nil {
                silenceStartTime = Date()
            } else if let start = silenceStartTime,
                      Date().timeIntervalSince(start) >= silenceAutoStopDuration {
                autoStopReason = .silence
                LiveActivityManager.shared.updatePaused(true)  // 灵动岛显示暂停状态
                _ = stopRecording()
                return
            }
        } else {
            silenceStartTime = nil
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorderService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("[Recorder] Recording finished unsuccessfully")
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("[Recorder] Encode error: \(error?.localizedDescription ?? "unknown")")
    }
}

// MARK: - Errors

enum AudioRecorderError: LocalizedError {
    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "需要麦克风权限才能录音，请在设置中开启"
        }
    }
}
