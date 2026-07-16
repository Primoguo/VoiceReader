// Knowledge/Services/KnowledgeService.swift
import Foundation
import SwiftData

/// 知识库 AI 对话服务
/// 基于沉淀的知识内容，提供专业级 AI 对话
/// 通过服务器中转调用通义千问，API Key 仅存储在服务器端
final class KnowledgeService {
    static let shared = KnowledgeService()

    private let apiClient = ServerAPIClient.shared

    /// 对话历史（多轮上下文，最多 10 轮）
    private var conversationHistory: [[String: String]] = []

    private init() {}

    // MARK: - System Prompt

    /// 知识库 AI 对话系统提示词（专业版）
    static let systemPrompt = """
    你是一名专业的知识管理助手，专门帮助用户深度理解和消化他们积累的知识内容。

    你的核心能力：
    1. 基于用户提供的知识内容，进行深入解析和拓展
    2. 将复杂概念拆解为易于理解的层次
    3. 帮助用户建立知识之间的联系
    4. 提供实践建议和行动指南

    ## 当前知识内容
    {knowledge_content}

    ## 回答规则
    - 直接开始回答，不要寒暄
    - 基于知识内容回答，不随意发散
    - 可以适当拓展相关知识点，帮助理解
    - 使用清晰的结构化表达（可以分点、举例）
    - 如果用户的问题超出知识范围，坦诚说明并给出你的理解
    - 保持专业但平易近人的语气
    - 默认使用中文

    ## 回答风格
    - 核心结论先行，再展开说明
    - 适当使用类比帮助理解
    - 对于行动类问题，给出具体步骤
    - 每次回答控制在 200 字以内
    """

    // MARK: - Public API

    /// 向 AI 提问（基于知识条目内容）
    func ask(question: String, knowledgeContent: String) async throws -> String {
        let prompt = Self.systemPrompt
            .replacingOccurrences(of: "{knowledge_content}", with: knowledgeContent)

        let response = try await apiClient.requestCompanion(
            question: question,
            context: knowledgeContent,
            history: conversationHistory,
            systemPrompt: prompt
        )

        // 记录对话历史（最多保留最近 10 轮）
        conversationHistory.append(["role": "user", "content": question])
        conversationHistory.append(["role": "assistant", "content": response])
        if conversationHistory.count > 20 {
            conversationHistory = Array(conversationHistory.suffix(20))
        }

        return response
    }

    /// 重置对话历史
    func resetConversation() {
        conversationHistory.removeAll()
    }

    // MARK: - Persistence

    /// 从 SwiftData 加载对话历史
    func loadConversation(entryId: UUID, context: ModelContext) -> [ChatEntry] {
        let predicate = #Predicate<KnowledgeChat> { $0.entryId == entryId }
        let descriptor = FetchDescriptor<KnowledgeChat>(predicate: predicate)
        guard let chat = try? context.fetch(descriptor).first else { return [] }
        let entries = chat.entries
        conversationHistory = entries.suffix(20).map { ["role": $0.role, "content": $0.content] }
        return entries
    }

    /// 保存对话到 SwiftData
    func saveConversation(entryId: UUID, context: ModelContext) {
        let entries = conversationHistory.map { ChatEntry(role: $0["role"] ?? "user", content: $0["content"] ?? "") }
        let predicate = #Predicate<KnowledgeChat> { $0.entryId == entryId }
        let descriptor = FetchDescriptor<KnowledgeChat>(predicate: predicate)
        if let existing = try? context.fetch(descriptor).first {
            existing.entries = entries
        } else {
            let chat = KnowledgeChat(entryId: entryId, entries: entries)
            context.insert(chat)
        }
        try? context.save()
    }

    /// 删除对话记录
    func clearConversation(entryId: UUID, context: ModelContext) {
        let predicate = #Predicate<KnowledgeChat> { $0.entryId == entryId }
        let descriptor = FetchDescriptor<KnowledgeChat>(predicate: predicate)
        if let chat = try? context.fetch(descriptor).first {
            context.delete(chat)
            try? context.save()
        }
    }
}
