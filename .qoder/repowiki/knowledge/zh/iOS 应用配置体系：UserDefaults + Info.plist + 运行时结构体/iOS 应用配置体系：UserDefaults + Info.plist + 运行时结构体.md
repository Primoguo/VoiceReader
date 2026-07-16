---
kind: configuration_system
name: iOS 应用配置体系：UserDefaults + Info.plist + 运行时结构体
category: configuration_system
scope:
    - '**'
source_files:
    - Resources/Info.plist
    - Models/VoiceConfig.swift
    - Models/ClonedVoice.swift
    - Models/LycheeLevelManager.swift
    - Services/ThemeManager.swift
    - ViewModels/SpeakerViewModel.swift
    - Views/SettingsView.swift
    - Views/SystemVoiceSelectView.swift
---

本仓库为 iOS/macOS SwiftUI 应用，未引入第三方配置框架（如 Swift Configuration、DotEnv、Feature Flags 等），而是采用 Apple 原生方案组合实现轻量级配置管理。整体分为三类：

1. **应用元数据与构建期常量** — `Resources/Info.plist` 集中存放 Bundle 标识、版本、UI 方向、后台模式等不可变元信息；通过 `$(PRODUCT_BUNDLE_IDENTIFIER)`、`$(DEVELOPMENT_LANGUAGE)` 等 Xcode 变量在 Scheme/Target 级别注入。
2. **用户偏好与持久化设置** — 全仓统一使用 `UserDefaults.standard` 直接读写，key 以字符串字面量散落在各模块中（如 `"voiceConfig"`、`"selectedSystemVoiceIdentifier"`、`"clonedVoices"`、`"totalMinutes"`、`"themeMode"` 等），无集中注册或命名空间隔离。
3. **运行时配置结构体** — `Models/VoiceConfig.swift` 定义 `TTSEngine` 枚举与 `VoiceConfig` 结构体，作为 TTS 引擎选择、语速/音调/音量/语言/音色 ID 等参数的载体，并通过 `Codable` 序列化后存入 UserDefaults。

关键文件与职责：
- `Resources/Info.plist`：应用元数据、权限声明、界面方向、LaunchScreen 等。
- `Models/VoiceConfig.swift`：TTS 相关运行时配置的数据模型，含默认值与预设档位。
- `Models/ClonedVoice.swift`：克隆音色列表与选中项的 UserDefaults 存取封装。
- `Models/LycheeLevelManager.swift`：学习时长等游戏化数据的 UserDefaults 存取。
- `Services/ThemeManager.swift`：主题模式的 UserDefaults 存取。
- `ViewModels/SpeakerViewModel.swift` 与 `Views/SettingsView.swift`：将 `VoiceConfig` 序列化为 JSON 后写入 key `"voiceConfig"`。
- `Views/SystemVoiceSelectView.swift`：系统语音标识符的 UserDefaults 存取。

架构约定与现状：
- 没有统一的 `ConfigurationService` 或 `SettingsManager` 单例，每个模块自行负责其 UserDefaults key 的读写。
- 所有 key 均为裸字符串，缺少集中常量定义，存在拼写不一致风险。
- 未发现 `.env`、`config.json`、`application.properties`、`Settings.bundle`、`featureFlag` 等常见配置形态。
- 未见环境变量读取逻辑（`ProcessInfo.processInfo.environment`）或远程配置拉取代码。

开发者应遵循的规则：
- 新增用户偏好时，优先复用已有模式：定义 `Codable` 结构体 → 用 `JSONEncoder/Decoder` 序列化为 Data → 通过 `UserDefaults.standard.set(data, forKey:)` 持久化。
- 若需新增全局配置 key，建议先在单一位置集中声明（例如新建 `Keys.swift`），避免散落字符串字面量。
- 对平台能力开关（如 `#available(iOS 17.0, *)`）已在 `TTSEngine.isSupported` 中体现，新增引擎时应同步更新该判断与 `requiresNetwork` 属性。
- 如需支持多环境（开发/测试/生产），可在 Xcode Scheme 中定义 `PRODUCT_BUNDLE_IDENTIFIER` 等变量，由 `Info.plist` 中的 `$(...)` 占位符消费，无需引入额外配置层。