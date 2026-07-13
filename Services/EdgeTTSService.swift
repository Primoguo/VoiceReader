// Knowledge/Services/EdgeTTSService.swift
import Foundation

/// Edge TTS 云端语音合成服务
/// 通过自建服务器（naolizhi.cn）中转调用微软 Edge TTS
/// 免费无限量，音质接近 Azure Neural TTS
final class EdgeTTSService {
    static let shared = EdgeTTSService()

    private let baseURL = "https://naolizhi.cn/api/tts"

    private init() {}

    // MARK: - 精选音色列表（中文优先）

    struct EdgeVoice: Identifiable, Codable, Hashable {
        let id: String       // voice_type, e.g. "zh-CN-XiaoxiaoNeural"
        let name: String     // 显示名
        let gender: String   // Female / Male
        let tag: String?     // 标签，如"推荐"、"新闻"

        static let recommendedChinese: [EdgeVoice] = [
            // 女声（靠前）
            EdgeVoice(id: "zh-CN-XiaoxiaoNeural",   name: "晓晓",   gender: "Female", tag: "推荐"),
            EdgeVoice(id: "zh-CN-XiaoyiNeural",     name: "晓伊",   gender: "Female", tag: nil),
            EdgeVoice(id: "zh-CN-XiaochenNeural",   name: "晓辰",   gender: "Female", tag: nil),
            EdgeVoice(id: "zh-CN-XiaohanNeural",    name: "晓涵",   gender: "Female", tag: nil),
            EdgeVoice(id: "zh-CN-XiaomengNeural",   name: "晓梦",   gender: "Female", tag: nil),
            EdgeVoice(id: "zh-CN-XiaomoNeural",     name: "晓墨",   gender: "Female", tag: nil),
            EdgeVoice(id: "zh-CN-XiaoruiNeural",    name: "晓睿",   gender: "Female", tag: nil),
            EdgeVoice(id: "zh-CN-XiaoshuangNeural", name: "晓双",   gender: "Female", tag: nil),
            EdgeVoice(id: "zh-CN-XiaoxuanNeural",   name: "晓萱",   gender: "Female", tag: nil),
            EdgeVoice(id: "zh-CN-XiaoyanNeural",     name: "晓颜",   gender: "Female", tag: nil),
            // 男声
            EdgeVoice(id: "zh-CN-YunyangNeural",    name: "云扬",   gender: "Male",   tag: "新闻"),
            EdgeVoice(id: "zh-CN-YunxiNeural",      name: "云希",   gender: "Male",   tag: nil),
            EdgeVoice(id: "zh-CN-YunjianNeural",    name: "云健",   gender: "Male",   tag: nil),
            EdgeVoice(id: "zh-CN-YunxiaNeural",     name: "云夏",   gender: "Male",   tag: nil),
            EdgeVoice(id: "zh-CN-YunyeNeural",      name: "云野",   gender: "Male",   tag: nil),
            EdgeVoice(id: "zh-CN-YunzeNeural",      name: "云泽",   gender: "Male",   tag: nil),
        ]

        static let recommendedCantonese: [EdgeVoice] = [
            EdgeVoice(id: "zh-HK-HiuGaaiNeural",  name: "曉佳",  gender: "Female", tag: "粤语"),
            EdgeVoice(id: "zh-HK-HiuMaanNeural",  name: "曉曼",  gender: "Female", tag: "粤语"),
            EdgeVoice(id: "zh-HK-WanLungNeural",   name: "雲龍",  gender: "Male",   tag: "粤语"),
        ]
    }

    /// 全部推荐音色（中文普通话 + 粤语）
    var allVoices: [EdgeVoice] {
        EdgeVoice.recommendedChinese + EdgeVoice.recommendedCantonese
    }

    // MARK: - 合成

    /// 调用 Edge TTS 服务合成语音
    /// - Parameters:
    ///   - text: 要合成的文本（最长 5000 字符）
    ///   - voice: 音色 ID（如 zh-CN-XiaoxiaoNeural）
    ///   - rate: 语速，内部值 0.1~2.0，会转换为 Edge TTS 的百分比格式
    /// - Returns: MP3 音频数据
    func synthesize(text: String, voice: String, rate: Float = 0.5) async throws -> Data {
        let edgeRate = convertRate(rate)

        // POST 请求 — 避免长文本导致 URL 超限（414 URI Too Long）
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "voice": voice,
            "rate": edgeRate
        ])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EdgeTTSError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw EdgeTTSError.apiError(statusCode: httpResponse.statusCode)
        }

        guard !data.isEmpty else {
            throw EdgeTTSError.noAudioData
        }

        return data
    }

    // MARK: - Private

    /// 将内部语速值 (0.1~2.0, 默认0.5) 转换为 Edge TTS 百分比格式
    /// 0.5 → "+0%", 1.0 → "+100%", 0.35 → "-30%"
    private func convertRate(_ rate: Float) -> String {
        // 内部 rate 0.5 = 正常速度，1.0 = 2倍速
        // Edge TTS: +0% = 正常, +100% = 2倍
        let percentage = Int((rate / 0.5 - 1.0) * 100)
        if percentage >= 0 {
            return "+\(percentage)%"
        } else {
            return "\(percentage)%"
        }
    }
}

// MARK: - Errors

enum EdgeTTSError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noAudioData
    case apiError(statusCode: Int)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "请求地址无效"
        case .invalidResponse:
            return "服务器响应异常"
        case .noAudioData:
            return "未获取到音频数据"
        case .apiError(let code):
            return "Edge TTS 请求失败（\(code)）"
        case .networkError(let error):
            return "网络错误：\(error.localizedDescription)"
        }
    }
}
