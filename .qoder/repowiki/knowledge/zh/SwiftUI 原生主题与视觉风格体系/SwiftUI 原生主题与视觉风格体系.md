---
kind: frontend_style
name: SwiftUI 原生主题与视觉风格体系
category: frontend_style
scope:
    - '**'
source_files:
    - Models/ThemeMode.swift
    - Services/ThemeManager.swift
    - App/KnowledgeApp.swift
    - Views/SettingsView.swift
    - Resources/Assets.xcassets/AccentColor.colorset/Contents.json
---

本仓库为 SwiftUI + SwiftData iOS 应用，前端样式完全基于 SwiftUI 原生能力，未引入任何第三方 UI 框架、CSS 或 SCSS。视觉风格通过以下机制实现：

1. **主题模式（ThemeMode）**：`Models/ThemeMode.swift` 定义 `system / light / dark` 三种模式枚举，提供对应的 SF Symbols 图标名和 `ColorScheme?` 映射。
2. **全局主题管理（ThemeManager）**：`Services/ThemeManager.swift` 作为单例 `ObservableObject`，使用 `@Published var mode` 暴露当前主题，并通过 `UserDefaults` 持久化；在 `App/KnowledgeApp.swift` 中通过 `.environmentObject(themeManager)` 注入根视图，配合 `.preferredColorScheme(themeManager.mode.colorScheme)` 控制全局明暗。
3. **颜色系统**：全仓统一使用 SwiftUI 语义色——`.primary`、`.secondary`、`.accentColor`、`.gray`、`.green`、`.orange` 等，以及 `Color(.systemGray6)` 这类系统灰阶，不硬编码十六进制色值。Accent 色由 `Resources/Assets.xcassets/AccentColor.colorset` 集中配置，供系统级 tint 自动继承。
4. **组件风格约定**：
   - 按钮/标签采用圆角矩形 + 低透明度背景强调态（如 `Color.accentColor.opacity(0.15)`）。
   - 设置项行使用 `HStack` + 右侧 `chevron.right` + 选中时显示 `checkmark` 的固定布局。
   - 状态标签（免费/推荐/即将推出）统一用 `caption2` 字号 + 彩色半透明背景 + `cornerRadius(4)` 的小徽章样式。
   - 滑块统一 `.tint(.accentColor)` 并配合快捷预设按钮组。
5. **无外部依赖**：未发现 Tailwind、Bootstrap、Styled Components、React Native StyleSheet 等跨平台样式方案，所有视觉表现均由 SwiftUI View Modifier 链式组合完成。

开发者应遵循的约定：
- 新增主题仅修改 `ThemeMode` 枚举，勿在业务代码中直接判断字符串。
- 颜色一律使用语义色，禁止硬编码 RGB/Hex。
- 强调色统一走 `.accentColor`，由 AccentColor colorset 驱动。
- 新增可复用的 UI 片段优先抽取为私有方法或独立小 View，保持 SettingsView 中的 HStack 列表风格一致。