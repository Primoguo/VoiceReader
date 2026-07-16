---
kind: error_handling
name: Swift 错误处理体系：LocalizedError + ErrorHandler 单例
category: error_handling
scope:
    - '**'
source_files:
    - Services/ErrorHandler.swift
    - Services/ServerAPIClient.swift
    - Services/EdgeTTSService.swift
    - Services/CosyVoiceService.swift
    - Services/TextExtractionService.swift
    - Services/SubscriptionManager.swift
    - ViewModels/SpeakerViewModel.swift
    - Views/ContentView.swift
---

## 1. 采用的错误处理系统

本项目基于 Swift 原生 async/throws 模型，结合 LocalizedError 协议与一个全局 ErrorHandler 单例，形成「领域错误枚举 + 统一 UI 提示」的两层架构。

- 异步错误传播：所有网络、文件 I/O、TTS 合成等可能失败的操作均使用 async throws 向上抛出错误，由调用方在 do/catch 中捕获。
- 领域错误类型：每个服务模块定义自己的 enum XxxError: LocalizedError，通过 errorDescription 提供用户可读的中文消息。
- 统一 UI 提示：ErrorHandler.shared.handle(_:context:) 将错误转换为 Alert 弹窗，并通过 @Published currentAlert 驱动 SwiftUI 展示。
- 日志记录：ErrorHandler.log(level:) 提供带 emoji 前缀的结构化日志输出（debug/info/warn/error）。

## 2. 关键文件与包

- Services/ErrorHandler.swift：全局错误处理单例，负责打印日志和弹出 Alert
- Services/ServerAPIClient.swift：中转服务器 API 客户端，定义 ServerAPIError
- Services/EdgeTTSService.swift：Edge TTS 服务，定义 EdgeTTSError
- Services/CosyVoiceService.swift：CosyVoice 服务，定义 CosyVoiceError
- Services/TextExtractionService.swift：文档文本提取，定义 ExtractionError
- Services/SubscriptionManager.swift：订阅管理，定义 StoreError
- ViewModels/SpeakerViewModel.swift：播放核心 ViewModel，集中 catch 并降级到系统 TTS
- Views/ContentView.swift：根视图，绑定 ErrorHandler.currentAlert 显示弹窗

## 3. 架构与约定

### 3.1 领域错误枚举模式

每个服务模块在其文件末尾以 // MARK: - Errors 分区定义错误枚举，遵循统一结构：
enum XxxError: LocalizedError { case invalidResponse; var errorDescription: String? { ... } }

已发现的错误枚举：ServerAPIError、EdgeTTSError、CosyVoiceError、ExtractionError、StoreError。

### 3.2 错误传播路径

底层 IO/网络 → 抛出具体 LocalizedError → Service 层封装为业务错误 → ViewModel 层 do/catch 捕获 → 调用 ErrorHandler.shared.handle(error) 或自行处理 → SwiftUI View 通过 @StateObject 监听 AlertInfo 弹窗。

### 3.3 降级策略

SpeakerViewModel 实现了云端 TTS 引擎出错时的自动降级：当 CosyVoice 或 EdgeTTS 报错时，临时切换回 Apple Neural TTS 继续播放，同时保留用户的原始引擎选择配置。

### 3.4 未覆盖区域

未发现 panic/recover 的使用；未发现中间件式的全局错误拦截器；错误处理分散在各层的 do/catch 块中，catch 分支风格不统一。

## 4. 开发者应遵循的规则

1. 定义领域错误：新增服务时添加 enum XxxError: LocalizedError，为每个 case 提供中文 errorDescription。
2. 使用 async throws：所有可能失败的 API 方法声明 async throws，不要吞掉错误。
3. 上层统一处理：在 ViewModel 或 View 的 do/catch 中优先调用 ErrorHandler.shared.handle(error, context: "...") 获得一致的用户反馈。
4. 区分可恢复与不可恢复错误：网络超时等可重试错误应在 UI 上提示用户重试；权限拒绝等不可恢复错误应引导用户前往设置。
5. 避免裸 catch：生产代码必须给出用户可见的错误信息。
6. 保持错误消息本地化：所有面向用户的错误描述必须是中文。