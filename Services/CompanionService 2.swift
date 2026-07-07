// Knowledge/Services/CompanionService.swift
import Foundation

/// AI 伴读服务 — 边听边问的交互式对话
/// 基于通义千问，支持多轮对话，携带当前朗读上下文
final class CompanionService {
    static let shared = CompanionService()

    private let baseURL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation"

    /// 对话历史（多轮上下文）
    private var conversationHistory: [[String: String]] = []

    private init() {}

    // MARK: - Public API

    /// 向 AI 提问（携带当前朗读上下文）
    /// - Parameters:
    ///   - question: 用户问题
    ///   - context: 当前朗读位置前后的文本片段
    ///   - maxTokens: 最大回复 token 数，默认 300（简短回答）
    /// - Returns: AI 的回复文本
    func ask(question: String, context: String, maxTokens: Int = 300) async throws -> String {
        guard let apiKey = UserDefaults.standard.string(forKey: "dashscope_api_key"),
              !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }

        // 构建系统提示：定义伴读角色 + 注入当前段落上下文
        let systemPrompt = """
        你是一位专业的阅读伴读助手。用户正在听一本书，当前正在朗读的段落如下：

        「\(context)」

        请基于以上上下文回答用户的问题。要求：
        - 回答简洁口语化，控制在 100 字以内
        - 如果问题超出文档范围，可以简短补充说明
        - 语气亲切自然，像朋友聊天一样
        """

        // 构建消息列表（system + 多轮历史 + 当前问题）
        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        messages.append(contentsOf: conversationHistory)
        messages.append(["role": "user", "content": question])

        let response = try await callAPI(apiKey: apiKey, messages: messages, maxTokens: maxTokens)

        // 记录对话历史（最多保留最近 10 轮）
        conversationHistory.append(["role": "user", "content": question])
        conversationHistory.append(["role": "assistant", "content": response])
        if conversationHistory.count > 20 {
            conversationHistory = Array(conversationHistory.suffix(20))
        }

        return response
    }

    /// 重置对话历史（切换文档时调用）
    func resetConversation() {
        conversationHistory.removeAll()
    }

    // MARK: - Private

    private func callAPI(apiKey: String, messages: [[String: String]], maxTokens: Int) async throws -> String {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "qwen-plus",
            "input": [
                "messages": messages
            ],
            "parameters": [
                "result_format": "message",
                "max_tokens": maxTokens,
                "temperature": 0.7
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw AIServiceError.invalidAPIKey
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.apiError(statusCode: httpResponse.statusCode, message: errorMsg)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any],
              let choices = output["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.invalidResponse
        }

        return content
    }
}
