---
kind: error_handling
name: Swift 错误处理体系：LocalizedError + 全局 ErrorHandler
category: error_handling
scope:
    - '**'
source_files:
    - Services/ErrorHandler.swift
    - Services/EdgeTTSService.swift
    - Services/ServerAPIClient.swift
    - Knowledge/Services/AISummaryService.swift
    - Knowledge/Services/CosyVoiceService.swift
---

## 1. 采用的错误处理体系

本项目采用 Swift 标准异步错误模型，核心由两部分组成：

- **领域级 `enum` + `LocalizedError`**：每个网络/合成服务定义自己的错误枚举，实现 `errorDescription` 提供用户可读的中文提示。
- **全局 `ErrorHandler` 单例**：集中记录日志、统一弹出 Alert，避免各层重复 UI 逻辑。

未使用 panic/recover、未引入第三方错误库（如 Result/AsyncSequence），也未在中间件层做统一拦截。

## 2. 关键文件与位置

| 角色 | 文件路径 |
|---|---|
| 全局错误处理中心 | `Services/ErrorHandler.swift` |
| Edge TTS 错误类型 | `Services/EdgeTTSService.swift`（`EdgeTTSError`） |
| 通用 API 客户端错误 | `Services/ServerAPIClient.swift`（`ServerAPIError`） |
| AI 摘要服务错误 | `Knowledge/Services/AISummaryService.swift`（`AIServiceError`） |
| CosyVoice 服务错误 | `Knowledge/Services/CosyVoiceService.swift`（`CosyVoiceError`） |

## 3. 架构与约定

### 3.1 错误枚举规范

所有业务错误均定义为 `enum XxxError: LocalizedError`，并通过 `switch self` 返回中文描述：

```swift
enum ServerAPIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case quotaExceeded
    case noAudioData
    case serverError(statusCode: Int, message: String)
    case networkError(Error)

    var errorDescription: String? { ... }
}
```

常见子类型包括：
- `invalidResponse` — JSON 解析失败 / 非 HTTPURLResponse
- `unauthorized` / `quotaExceeded` — 鉴权与配额类错误
- `noAudioData` — 音频接口未返回有效数据
- `serverError(statusCode:message:)` — 兜底，携带原始状态码与消息
- `networkError(Error)` — 包装底层 `URLError`

### 3.2 抛出策略

- 网络请求方法签名统一为 `async throws -> T`，通过 `try await URLSession.shared.data(for:)` 获取响应后，用 `guard` + `throw` 校验状态码与数据完整性。
- 对可恢复的局部问题（如 JSON 字段缺失）直接抛出自定义错误；对不可恢复的（如 URL 无效）也抛错而非静默降级。
- 部分持久化/序列化调用使用 `try?` 吞掉异常并返回空集合或 nil（如 `ClonedVoice`、`SummaryResult` 的本地读写），属于"容错读取"场景。

### 3.3 全局 ErrorHandler

`ErrorHandler.shared` 提供两个入口：

- `handle(_ error:context:)` — 优先取 `LocalizedError.errorDescription`，否则退化为 `localizedDescription`；打印带 emoji 前缀的日志，并在主线程发布 `currentAlert` 供 SwiftUI 弹窗。
- `log(_:level:)` — 仅输出 debug/info/warn/error 四级日志，不弹窗。

UI 层通过 `@Published var currentAlert` 订阅并展示 Alert，形成"服务抛错 → 全局处理器 → 统一弹窗"的单向链路。

### 3.4 调用方消费模式

上层 ViewModel/Service 通常以 `do-catch` 捕获具体错误枚举，再委托给 `ErrorHandler.shared.handle(error, context:)`，或直接 `throw` 让更高层聚合。

## 4. 开发者应遵循的规则

1. **新增错误必须实现 `LocalizedError`**：为每个分支提供清晰的用户可见中文描述，禁止裸 `String` 错误。
2. **网络层统一抛错**：HTTP 非 200、JSON 解析失败、缺少必要字段等一律 `throw` 自定义错误，不在网络层做静默降级。
3. **UI 层只负责展示**：不要在 Service 里直接弹 Alert，统一走 `ErrorHandler.shared.handle`。
4. **可恢复的本地 I/O 可用 `try?`**：仅对本地缓存/偏好设置这类"读不到就继续运行"的场景使用 `try?`，对外部依赖一律 `throws`。
5. **不要使用 `fatalError` / `preconditionFailure`**：生产代码中未发现此类调用，应保持错误可被捕获和上报。
6. **上下文信息**：调用 `ErrorHandler.handle` 时传入有意义的 `context` 字符串，便于日志定位。

## 5. 不足与建议

- 当前无结构化日志框架，仅 `print` 输出，建议接入 OSLog 或第三方 logger。
- 未对 `NetworkError` 做重试/退避策略，可在 `ErrorHandler` 或上层封装。
- 尚未建立统一的错误码映射表，跨端对接时可考虑将 `statusCode` 与业务码关联。
