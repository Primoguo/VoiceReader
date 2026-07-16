// Knowledge/Views/KnowledgeDetailView.swift
import SwiftUI
import SwiftData

/// 知识条目详情页 — 内容展示 + AI 对话
struct KnowledgeDetailView: View {
    let entry: KnowledgeEntry

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatEntry] = []
    @State private var inputText = ""
    @State private var isAsking = false
    @State private var showChat = false
    @FocusState private var inputFocused: Bool

    private let service = KnowledgeService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 头部信息
                header

                // 正文内容
                contentSection

                Divider()
                    .padding(.vertical, 16)

                // AI 对话区域
                chatSection
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle(entry.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        deleteEntry()
                    } label: {
                        Label("删除知识", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear { loadChat() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: entry.source.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Text(entry.category.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .foregroundColor(.white)
                    .background(Capsule().fill(categoryColor(entry.category)))

                Spacer()

                Text(entry.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Content

    private var contentSection: some View {
        Text(entry.content)
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(.primary)
            .lineSpacing(6)
            .padding(.top, 12)
    }

    // MARK: - Chat Section

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // AI 对话标题
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                Text("AI 知识对话")
                    .font(.system(size: 16, weight: .medium))
                Spacer()
                if !messages.isEmpty {
                    Button {
                        clearChat()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // 欢迎语（空对话时）
            if messages.isEmpty {
                welcomeView
            }

            // 消息列表
            ForEach(messages) { msg in
                chatBubble(msg)
            }

            // 输入栏
            inputBar
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 12) {
            Text("基于这份知识内容，你可以向 AI 提问")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                quickButton("核心要点是什么？")
                quickButton("如何应用到实践中？")
            }
            HStack(spacing: 8) {
                quickButton("帮我总结一下")
                quickButton("还有哪些相关知识？")
            }
        }
        .padding(.vertical, 12)
    }

    private func quickButton(_ text: String) -> some View {
        Button(text) {
            sendQuestion(text)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundColor(.primary)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    // MARK: - Chat Bubble

    private func chatBubble(_ msg: ChatEntry) -> some View {
        let isUser = msg.role == "user"
        return HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(isUser ? "你" : "AI 助手")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(msg.content)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isUser ? Color.primary.opacity(0.06) : Color(.systemGray6))
                    .foregroundColor(.primary)
                    .cornerRadius(16)
            }

            if !isUser { Spacer(minLength: 40) }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("问我关于这份知识的问题...", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($inputFocused)
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .primary)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAsking)
        }
    }

    // MARK: - Actions

    private func loadChat() {
        messages = service.loadConversation(entryId: entry.id, context: modelContext)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        sendQuestion(text)
    }

    private func sendQuestion(_ question: String) {
        // 添加用户消息
        let userEntry = ChatEntry(role: "user", content: question)
        messages.append(userEntry)

        // 添加 loading 占位
        messages.append(ChatEntry(role: "assistant", content: ""))
        let loadingIndex = messages.count - 1

        isAsking = true

        Task {
            do {
                let response = try await service.ask(
                    question: question,
                    knowledgeContent: entry.content
                )
                await MainActor.run {
                    messages[loadingIndex] = ChatEntry(role: "assistant", content: response)
                    service.saveConversation(entryId: entry.id, context: modelContext)
                    isAsking = false
                }
            } catch {
                await MainActor.run {
                    messages[loadingIndex] = ChatEntry(role: "assistant", content: "请求失败：\(error.localizedDescription)")
                    isAsking = false
                }
            }
        }
    }

    private func clearChat() {
        messages.removeAll()
        service.resetConversation()
        service.clearConversation(entryId: entry.id, context: modelContext)
    }

    private func deleteEntry() {
        modelContext.delete(entry)
        try? modelContext.save()
        dismiss()
    }

    private func categoryColor(_ category: KnowledgeCategory) -> Color {
        switch category {
        case .meeting:  return .blue
        case .creative: return .orange
        case .todo:     return .green
        case .general:  return .gray
        }
    }
}
