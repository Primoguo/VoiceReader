---
kind: configuration_system
name: 基于 UserDefaults 与 Info.plist 的轻量配置系统
category: configuration_system
scope:
    - '**'
source_files:
    - Resources/Info.plist
    - App/KnowledgeApp.swift
    - Services/ThemeManager.swift
    - Models/VoiceConfig.swift
    - Models/ClonedVoice.swift
    - Services/CompanionService.swift
---

本仓库未引入第三方配置框架，采用 iOS 原生方案组合实现应用配置：Info.plist 承载构建期/平台级元数据，UserDefaults 承载用户运行时偏好，各 Service/Model 自行维护少量键值对。整体为“无集中式配置中心”的扁平风格。

## 1. 使用的系统与工具
- **Info.plist**（`Resources/Info.plist`）：Bundle 标识、显示名、后台模式、界面方向等打包期配置。
- **UserDefaults.standard**：所有用户偏好与运行时开关均直接读写该单例，无统一封装层。
- **SwiftData ModelConfiguration**：在 `App/KnowledgeApp.swift` 中通过 `ModelContainer(configurations:)` 声明数据模型容器。
- **SwiftUI EnvironmentObject**：`ThemeManager` 以 `@Published` + `environmentObject` 注入到视图树，作为主题配置的响应式来源。

## 2. 关键文件与包
- `Resources/Info.plist` — 应用元信息与权限声明
- `App/KnowledgeApp.swift` — SwiftData 容器与全局环境对象注册
- `Services/ThemeManager.swift` — 主题模式持久化（UserDefaults → @Published）
- `Models/VoiceConfig.swift` — TTS 引擎枚举与语音参数结构体定义（默认值集中于此）
- `Models/ClonedVoice.swift` — VoiceStore 静态类封装克隆音色列表与选中项的 UserDefaults 存取
- `Services/CompanionService.swift` — AI 伴读难度、最近文档 ID 等状态直接读写 UserDefaults
- `ViewModels/SpeakerViewModel.swift`、`Views/SystemVoiceSelectView.swift`、`Views/SettingsView.swift` — 多处直接写入 `voiceConfig`、`selectedSystemVoiceIdentifier` 等 key

## 3. 架构与约定
- **分层职责**：
  - Info.plist 只放不可变/构建期常量；
  - VoiceConfig/TTSEngine 提供“配置结构 + 默认值 + 能力判断”；
  - ThemeManager 是唯一对外暴露的 ObservableObject 配置源；
  - 其余 Service/Model 各自持有少量 UserDefaults key，充当“私有配置”。
- **持久化策略**：
  - 简单标量（字符串、整数、布尔）→ 直接 `UserDefaults.standard.set(_:forKey:)`；
  - 复杂对象（如 `[ClonedVoice]`、`VoiceConfig`）→ JSON 编码后以 Data 形式存入。
- **运行时切换**：
  - 主题通过 `ThemeManager.shared.mode` 的 `@Published` 驱动 SwiftUI 自动刷新；
  - 其他配置（语速、引擎、音色 ID）由 View/ViewModel 修改 UserDefaults，下次读取时生效。

## 4. 开发者应遵循的规则
1. **新增用户偏好**优先使用 `UserDefaults.standard`，并为 key 抽取为 `static let` 常量，避免魔法字符串散落各处。
2. **结构化配置**（如 TTS 参数）集中在 `VoiceConfig` 等 struct 中定义默认值，并通过 JSON 编解码持久化。
3. **需要响应式更新**的配置（如主题）应封装为 `ObservableObject` + `@Published`，并在 App 启动时通过 `.environmentObject` 注入。
4. **敏感信息**（API Key、订阅令牌）不落地 UserDefaults，仅存于服务端或 Keychain（当前代码未见 Keychain 使用，需后续补充）。
5. **Info.plist 变更**走 Xcode Target 设置或脚本生成，不在运行时代码拼接 Bundle 字段。

## 5. 已知问题与改进建议
- UserDefaults key 命名缺乏统一前缀与命名空间，存在冲突风险（如 `companion_lastDocumentId`、`voiceConfig`、`themeMode` 混用）。
- 缺少统一的 Configuration 入口类，导致读取分散、难以做版本迁移或默认值回退。
- 尚未发现 .env / Feature Flag / 远程配置加载逻辑，如需灰度或 A/B 测试需引入集中式配置服务。