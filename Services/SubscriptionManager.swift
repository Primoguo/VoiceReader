// Knowledge/Services/SubscriptionManager.swift
import Foundation
import StoreKit

/// 订阅管理器 — 管理 Premium 订阅状态
/// 使用 StoreKit 2，支持订阅检查、购买和恢复
@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    // MARK: - Published State

    /// 用户是否已订阅 Premium
    @Published var isPremium: Bool = false

    /// 是否正在加载/检查订阅状态
    @Published var isLoading: Bool = false

    /// 可用的订阅产品列表
    @Published var products: [Product] = []

    /// 当前活跃的订阅（如果有）
    @Published var currentSubscription: Product.SubscriptionInfo? = nil

    /// 订阅起始日期（从 StoreKit 2 获取）
    @Published var subscriptionStartDate: Date? = nil

    // MARK: - Configuration

    // TODO: [待办] 在 App Store Connect 中配置 IAP 产品后，替换为实际的产品 ID
    // 配置步骤：App Store Connect → 你的 App → 订阅 → 创建订阅组 → 添加月订阅 + 年订阅
    private let productIDs = ["com.knowledge.premium.monthly", "com.knowledge.premium.yearly"]

    // MARK: - 云端转写配额

    /// 每月云端转写额度（秒）：10 小时
    static let monthlyTranscriptionQuota: TimeInterval = 10 * 3600

    /// 本周期已使用的云端转写秒数
    var transcriptionUsedSeconds: TimeInterval {
        get { UserDefaults.standard.double(forKey: "transcription_used_seconds") }
        set { UserDefaults.standard.set(newValue, forKey: "transcription_used_seconds") }
    }

    /// 上一次配额重置的订阅周期序号
    var lastResetCycleIndex: Int {
        get { UserDefaults.standard.integer(forKey: "transcription_last_reset_cycle") }
        set { UserDefaults.standard.set(newValue, forKey: "transcription_last_reset_cycle") }
    }

    /// 本周期剩余云端转写秒数
    var remainingTranscriptionSeconds: TimeInterval {
        autoResetQuotaIfNeeded()
        return max(0, Self.monthlyTranscriptionQuota - transcriptionUsedSeconds)
    }

    /// 是否还有云端转写额度
    var canUseCloudTranscription: Bool {
        isPremium && remainingTranscriptionSeconds > 0
    }

    /// 下一个配额重置日期（基于订阅周期）
    var transcriptionQuotaResetDate: Date? {
        guard let start = subscriptionStartDate else { return nil }
        let now = Date()
        let cal = Calendar.current
        // 找到当前所处的周期序号
        let monthsSinceStart = cal.dateComponents([.month], from: start, to: now).month ?? 0
        // 下一个重置日 = 订阅起始日 + (monthsSinceStart + 1) 个月
        return cal.date(byAdding: .month, value: monthsSinceStart + 1, to: start)
    }

    /// 消耗云端转写配额
    func consumeTranscriptionQuota(seconds: TimeInterval) {
        guard isPremium else { return }
        autoResetQuotaIfNeeded()
        transcriptionUsedSeconds += seconds
    }

    /// 自动重置配额（当进入新的订阅周期时）
    private func autoResetQuotaIfNeeded() {
        guard let start = subscriptionStartDate else { return }
        let now = Date()
        let monthsSinceStart = Calendar.current.dateComponents([.month], from: start, to: now).month ?? 0
        if monthsSinceStart > lastResetCycleIndex {
            transcriptionUsedSeconds = 0
            lastResetCycleIndex = monthsSinceStart
        }
    }

    // MARK: - AI 限免配额

    /// 每个 AI 功能的免费体验次数
    static let freeTrialLimit = 1

    /// AI 总结已用次数
    var aiSummaryUsed: Int {
        get { UserDefaults.standard.integer(forKey: "ai_summary_used") }
        set { UserDefaults.standard.set(newValue, forKey: "ai_summary_used") }
    }

    /// AI 伴读已用次数
    var aiCompanionUsed: Int {
        get { UserDefaults.standard.integer(forKey: "ai_companion_used") }
        set { UserDefaults.standard.set(newValue, forKey: "ai_companion_used") }
    }

    /// 是否可以使用 AI 总结（Premium 或有免费次数）
    var canUseAISummary: Bool {
        isPremium || aiSummaryUsed < Self.freeTrialLimit
    }

    /// 是否可以使用 AI 伴读（Premium 或有免费次数）
    var canUseAICompanion: Bool {
        isPremium || aiCompanionUsed < Self.freeTrialLimit
    }

    /// 消耗一次 AI 总结免费次数（仅非 Premium 用户）
    func consumeAISummaryTrial() {
        guard !isPremium else { return }
        aiSummaryUsed += 1
    }

    /// 消耗一次 AI 伴读免费次数（仅非 Premium 用户）
    func consumeAICompanionTrial() {
        guard !isPremium else { return }
        aiCompanionUsed += 1
    }

    // MARK: - Init

    private init() {
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }

    // MARK: - Public API

    /// 加载可用订阅产品
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: productIDs)
        } catch {
            print("加载订阅产品失败: \(error.localizedDescription)")
            products = []
        }
    }

    /// 检查当前订阅状态，并从 StoreKit 2 获取订阅起始日期
    func checkSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.revocationDate == nil {
                    isPremium = true
                    subscriptionStartDate = transaction.originalPurchaseDate
                    return
                }
            }
        }
        isPremium = false
        subscriptionStartDate = nil
    }

    /// 购买订阅
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // 验证交易
            let transaction = try checkVerified(verification)
            // 完成交易（告诉 App Store 已处理）
            await transaction.finish()
            // 刷新订阅状态
            await checkSubscriptionStatus()
            return true

        case .userCancelled:
            return false

        case .pending:
            // 等待家长审批等
            return false

        @unknown default:
            return false
        }
    }

    /// 恢复购买（用户换设备/重装 App 时使用）
    func restorePurchases() async {
        try? await AppStore.sync()
        await checkSubscriptionStatus()
    }

    // MARK: - Private

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Errors

    enum StoreError: LocalizedError {
        case failedVerification

        var errorDescription: String? {
            switch self {
            case .failedVerification:
                return "购买验证失败，请重试"
            }
        }
    }
}
