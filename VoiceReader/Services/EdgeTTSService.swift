// VoiceReader/Services/EdgeTTSService.swift
import Foundation
import AVFoundation
import CryptoKit

/// Edge TTS 语音合成引擎（微软免费 TTS）
/// 通过 WebSocket 连接微软语音服务，流式接收音频并播放
final class EdgeTTSService: NSObject, SpeechSynthesizerProtocol {

    // MARK: - SpeechSynthesizerProtocol

    private(set) var state: PlaybackState = .idle
    var onPositionChange: ((Int) -> Void)?
    var onRangeChange: ((NSRange) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Internal State

    private var fullText: String = ""
    private var config: VoiceConfig = .defaultConfig
    private var currentPosition = 0
    private var isManuallyStopped = false

    // Audio playback
    private var audioPlayer: AVAudioPlayer?
    private var audioData = Data()

    // WebSocket
    private var webSocketTask: URLSessionWebSocketTask?
    private let urlSession: URLSession
    private var isConnected = false
    private var pendingSSML: String?

    // Chunking
    private var chunkIndex = 0
    private var totalChunks = 0
    private let maxCharsPerChunk = 1000

    // Estimated timing
    private static let charsPerSecond: Int = 4
    private var estimatedChunkDuration: TimeInterval = 0

    // Edge TTS voice mapping
    static let voiceMap: [String: String] = [
        "zh-CN": "zh-CN-XiaoxiaoNeural",
        "zh-HK": "zh-HK-HiuMaanNeural",
        "en-US": "en-US-JennyNeural",
        "en-GB": "en-GB-SoniaNeural",
        "ja-JP": "ja-JP-NanamiNeural",
        "ko-KR": "ko-KR-SunHiNeural",
    ]

    // MARK: - Init

    override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.urlSession = URLSession(configuration: config)
        super.init()
    }

    deinit {
        stop()
    }

    // MARK: - Public API

    func speak(text: String, from position: Int, config: VoiceConfig) {
        stop()

        self.fullText = text
        self.config = config
        self.currentPosition = position
        self.isManuallyStopped = false
        self.chunkIndex = 0

        let nsText = text as NSString
        guard position < nsText.length else {
            updateState(.finished)
            return
        }

        // 估算总字符数
        let remainingText = nsText.substring(from: position)
        self.totalChunks = max(1, (remainingText.count + maxCharsPerChunk - 1) / maxCharsPerChunk)

        // 开始第一个 chunk
        speakNextChunk()
    }

    func pause() {
        guard state == .playing else { return }
        audioPlayer?.pause()
        updateState(.paused)
    }

    func resume() {
        guard state == .paused else { return }
        audioPlayer?.play()
        updateState(.playing)
    }

    func stop() {
        isManuallyStopped = true
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        audioPlayer?.stop()
        audioPlayer = nil
        audioData = Data()
        pendingSSML = nil
        updateState(.idle)
    }

    func skipForward(by seconds: TimeInterval) {
        let charsToSkip = Int(seconds) * Self.charsPerSecond
        let nsText = fullText as NSString
        let newPos = min(currentPosition + charsToSkip, nsText.length)
        stop()
        if newPos < nsText.length {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.speak(text: self?.fullText ?? "", from: newPos, config: self?.config ?? .defaultConfig)
            }
        } else {
            updateState(.finished)
        }
    }

    func skipBackward(by seconds: TimeInterval) {
        let newPos = max(currentPosition - Int(seconds) * Self.charsPerSecond, 0)
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.speak(text: self?.fullText ?? "", from: newPos, config: self?.config ?? .defaultConfig)
        }
    }

    // MARK: - Private: Chunk Management

    private func speakNextChunk() {
        guard !isManuallyStopped else { return }

        let nsText = fullText as NSString
        let start = currentPosition

        guard start < nsText.length else {
            updateState(.finished)
            return
        }

        let remaining = nsText.length - start
        var chunkLength = min(remaining, maxCharsPerChunk)

        // 在自然断点截断
        if start + chunkLength < nsText.length {
            let searchStart = max(start + chunkLength - 150, start)
            let searchLength = min(150, nsText.length - searchStart)
            let searchRange = NSRange(location: searchStart, length: searchLength)
            for marker in ["。", "！", "？", "\n\n", ". ", "! ", "? "] {
                let markerRange = nsText.range(of: marker, options: [], range: searchRange)
                if markerRange.location != NSNotFound {
                    chunkLength = markerRange.location + markerRange.length - start
                    break
                }
            }
        }

        let chunk = nsText.substring(with: NSRange(location: start, length: chunkLength))
        let chunkRange = NSRange(location: start, length: chunkLength)

        // 估算这个 chunk 的播放时长（Edge TTS 平均每秒约 4-5 个汉字）
        self.estimatedChunkDuration = Double(chunkLength) / Double(Self.charsPerSecond)

        // 生成 SSML
        let voiceName = Self.voiceMap[config.language] ?? Self.voiceMap["zh-CN"]!
        let rateStr: String
        // config.rate 范围 0.1~2.0，基准 0.5 = 正常语速
        // Edge TTS 的 prosody rate 对中文加速很激进，使用平缓映射：
        //   rate=0.5 → "+0%" (正常), rate=1.0 → "+30%" (1.3x), rate=2.0 → "+60%" (1.6x)
        let edgeRate = config.rate / 0.5 // 0.5 → 1.0
        let mappedRate = 1.0 + (edgeRate - 1.0) * 0.3
        if mappedRate <= 0.5 {
            rateStr = "-50%"
        } else if mappedRate >= 2.0 {
            rateStr = "+100%"
        } else {
            let pct = Int((mappedRate - 1.0) * 100)
            rateStr = pct >= 0 ? "+\(pct)%" : "\(pct)%"
        }

        let ssml = """
        <speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="http://www.w3.org/2001/mstts" xml:lang="\(config.language)">
            <voice name="\(voiceName)">
                <prosody rate="\(rateStr)" pitch="\(config.pitchMultiplier > 1 ? "+\(Int((config.pitchMultiplier - 1) * 100))%" : config.pitchMultiplier < 1 ? "\(Int((config.pitchMultiplier - 1) * 100))%" : "+0%")">
                    \(chunk.xmlEscaped)
                </prosody>
            </voice>
        </speak>
        """

        // 发送到 Edge TTS
        synthesize(ssml: ssml, chunkRange: chunkRange)
    }

    private func moveToNextChunk() {
        let nsText = fullText as NSString
        if currentPosition >= nsText.length {
            onPositionChange?(nsText.length)
            updateState(.finished)
        } else {
            speakNextChunk()
        }
    }

    // MARK: - Sec-MS-GEC Token Generation

    private static let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
    private static let winEpochOffset: UInt64 = 11644473600
    private static let secMsGecVersion = "1-143.0.3650.75"

    /// 生成 Microsoft Edge TTS 所需的 Sec-MS-GEC 请求头值
    /// 算法参考 edge-tts 项目：https://github.com/rany2/edge-tts
    private static func generateSecMsGec() -> String {
        let unixTime = UInt64(Date().timeIntervalSince1970)
        var ticks = unixTime + winEpochOffset
        ticks -= ticks % 300
        ticks *= 10_000_000
        let plain = "\(ticks)\(trustedClientToken)"
        guard let data = plain.data(using: .ascii) else { return "" }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02X", $0) }.joined()
    }

    /// 生成 Edge TTS 所需的 X-Timestamp 格式时间戳
    /// 格式: "Thu Jan 01 1970 00:00:00 GMT+0000 (Coordinated Universal Time)"
    private static func generateTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE MMM dd yyyy HH:mm:ss 'GMT+0000 (Coordinated Universal Time)'"
        return formatter.string(from: Date())
    }

    // MARK: - WebSocket Communication

    private func synthesize(ssml: String, chunkRange: NSRange) {
        // Edge TTS WebSocket endpoint with all required params
        let connectionId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        var components = URLComponents(string: "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1")!
        components.queryItems = [
            URLQueryItem(name: "TrustedClientToken", value: Self.trustedClientToken),
            URLQueryItem(name: "ConnectionId", value: connectionId),
            URLQueryItem(name: "Sec-MS-GEC", value: Self.generateSecMsGec()),
            URLQueryItem(name: "Sec-MS-GEC-Version", value: Self.secMsGecVersion),
        ]

        guard let url = components.url else {
            updateState(.idle)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        // 模拟 Edge 浏览器 WebSocket 请求头（与 edge-tts constants.py 保持一致）
        request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0", forHTTPHeaderField: "User-Agent")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("gzip, deflate, br, zstd", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()

        isConnected = true
        audioData = Data()
        pendingSSML = ssml

        // 发送配置消息（与 edge-tts communicate.py 格式完全一致）
        let timestamp = Self.generateTimestamp()
        let configMessage = """
        X-Timestamp:\(timestamp)\r\nContent-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"true"},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}
        """

        webSocketTask?.send(.string(configMessage)) { [weak self] error in
            if let error = error {
                print("🔊 Edge TTS config error: \(error)")
                self?.handleError()
                return
            }
            // 发送 SSML（X-Timestamp 带 Z 后缀是微软的已知 bug）
            let requestId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            let ssmlMessage = "X-RequestId:\(requestId)\r\nContent-Type:application/ssml+xml\r\nX-Timestamp:\(timestamp)Z\r\nPath:ssml\r\n\r\n\(ssml)"
            self?.webSocketTask?.send(.string(ssmlMessage)) { error in
                if let error = error {
                    print("🔊 Edge TTS SSML error: \(error)")
                    self?.handleError()
                    return
                }
                // 开始接收音频数据
                self?.receiveAudioData(chunkRange: chunkRange)
            }
        }
    }

    private func receiveAudioData(chunkRange: NSRange) {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    // 检查是否是音频数据（包含 Path:audio 标记）
                    if let str = String(data: data, encoding: .utf8), str.contains("Path:audio") {
                        // 提取音频数据（跳过 headers）
                        if let audioStart = self.findAudioDataStart(in: data) {
                            self.audioData.append(data.subdata(in: audioStart..<data.count))
                        } else {
                            self.audioData.append(data)
                        }
                    } else if data.count > 100 {
                        // 可能是纯音频数据
                        self.audioData.append(data)
                    } else if let str = String(data: data, encoding: .utf8), str.contains("Path:turn.end") {
                        // 音频流结束，开始播放
                        self.playAudioData(chunkRange: chunkRange)
                        return
                    }
                    // 继续接收
                    self.receiveAudioData(chunkRange: chunkRange)

                case .string(let str):
                    if str.contains("Path:turn.end") {
                        self.playAudioData(chunkRange: chunkRange)
                        return
                    }
                    self.receiveAudioData(chunkRange: chunkRange)

                @unknown default:
                    self.receiveAudioData(chunkRange: chunkRange)
                }

            case .failure(let error):
                print("🔊 Edge TTS receive error: \(error)")
                // 如果已经有音频数据，尝试播放
                if !self.audioData.isEmpty {
                    self.playAudioData(chunkRange: chunkRange)
                } else {
                    self.handleError()
                }
            }
        }
    }

    private func findAudioDataStart(in data: Data) -> Int? {
        guard let str = String(data: data, encoding: .utf8) else { return nil }
        if let audioHeaderEnd = str.range(of: "Path:audio\r\n") {
            let offset = str.distance(from: str.startIndex, to: audioHeaderEnd.upperBound)
            // 跳过 Content-Type header
            let remaining = str[audioHeaderEnd.upperBound...]
            if let ctEnd = remaining.range(of: "\r\n\r\n") {
                let totalOffset = offset + str.distance(from: remaining.startIndex, to: ctEnd.upperBound)
                return totalOffset
            }
            return offset
        }
        return nil
    }

    private func playAudioData(chunkRange: NSRange) {
        guard !isManuallyStopped, !audioData.isEmpty else {
            cleanupConnection()
            moveToNextChunk()
            return
        }

        // 更新状态和位置
        currentPosition = chunkRange.location + chunkRange.length
        onPositionChange?(currentPosition)

        // 通知范围变化（模拟高亮整个 chunk）
        onRangeChange?(chunkRange)

        do {
            // 配置音频会话
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.allowBluetoothHFP, .allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.volume = config.volume
            audioPlayer?.delegate = audioDelegate
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            updateState(.playing)

            // 启动位置追踪 Timer
            startPositionTracking(chunkRange: chunkRange)
        } catch {
            print("🔊 Edge TTS playback error: \(error)")
            cleanupConnection()
            moveToNextChunk()
        }
    }

    // MARK: - Position Tracking

    private var positionTimer: Timer?

    private func startPositionTracking(chunkRange: NSRange) {
        positionTimer?.invalidate()
        let startTime = Date()
        let chunkLength = chunkRange.length
        let startPos = chunkRange.location

        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / self.estimatedChunkDuration, 1.0)
            let currentPos = startPos + Int(Double(chunkLength) * progress)
            self.onPositionChange?(min(currentPos, startPos + chunkLength))
        }
    }

    // MARK: - Audio Delegate (internal class)

    private lazy var audioDelegate = AudioPlayerDelegate(service: self)

    private final class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
        weak var service: EdgeTTSService?

        init(service: EdgeTTSService) {
            self.service = service
        }

        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            guard let service else { return }
            service.positionTimer?.invalidate()
            service.positionTimer = nil
            service.audioPlayer = nil
            service.audioData = Data()
            service.cleanupConnection()
            service.moveToNextChunk()
        }

        func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
            print("🔊 Edge TTS decode error: \(error?.localizedDescription ?? "unknown")")
            guard let service else { return }
            service.positionTimer?.invalidate()
            service.positionTimer = nil
            service.audioPlayer = nil
            service.audioData = Data()
            service.cleanupConnection()
            service.moveToNextChunk()
        }
    }

    // MARK: - Helpers

    private func handleError() {
        cleanupConnection()
        // 如果还没有播放过任何内容，通知上层降级
        if chunkIndex == 0 && audioData.isEmpty {
            updateState(.idle)
            let error = NSError(domain: "EdgeTTSService", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Edge TTS 连接失败，已自动切换到系统 TTS"])
            onError?(error)
        } else {
            moveToNextChunk()
        }
    }

    private func cleanupConnection() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    private func updateState(_ newState: PlaybackState) {
        DispatchQueue.main.async { [weak self] in
            self?.state = newState
        }
    }
}

// MARK: - String Extension for XML Escaping

private extension String {
    var xmlEscaped: String {
        self.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
