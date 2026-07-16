---
kind: dependency_management
name: iOS 原生依赖管理（无第三方包管理器）
category: dependency_management
scope:
    - '**'
source_files:
    - Knowledge.xcodeproj/project.pbxproj
    - README.md
    - copy_pbxproj.py
    - fix_pbxproj.py
    - modify_pbxproj.py
---

本项目为纯 iOS SwiftUI 应用，**未使用任何第三方依赖管理工具**（如 Swift Package Manager、CocoaPods、Carthage），所有依赖均为 Apple 平台框架与系统 SDK。依赖管理完全由 Xcode 项目文件 `Knowledge.xcodeproj/project.pbxproj` 驱动，通过手动添加 Frameworks Build Phase 和 Link Binary With Libraries 阶段来声明对系统框架的链接关系。

### 依赖来源与分类
- **系统框架**：仅引入 Apple 官方框架，包括 Foundation、UIKit、SwiftUI、AVFoundation、PDFKit、WebKit 等，全部随 iOS SDK 提供，无需额外安装或版本锁定。
- **无外部库**：项目中不存在任何 vendored 二进制、私有仓库或第三方源码，所有功能均基于系统 API 实现（如 AVSpeechSynthesizer、MPNowPlayingInfoCenter、SwiftData 等）。
- **网络请求**：HTTP 调用直接使用 `URLSession`，未封装独立网络层或使用第三方 HTTP 客户端。

### 构建与链接方式
- 依赖声明集中在 `project.pbxproj` 的 `PBXFrameworksBuildPhase` 段中，当前为空数组，表明未显式链接额外框架；实际使用的系统框架由 Xcode 根据 import 语句自动解析。
- 项目通过 `Signing & Capabilities` 中的 Background Modes → Audio 能力开关启用后台音频播放权限，属于运行时能力而非编译期依赖。
- 根目录存在 `copy_pbxproj.py`、`fix_pbxproj.py`、`modify_pbxproj.py` 三个 Python 脚本，用于手工维护 pbxproj 结构，侧面印证了项目缺乏自动化依赖管理机制。

### 开发者约定
- 新增系统框架时需在 Xcode 中手动添加到 Target → General → Frameworks, Libraries, and Embedded Content。
- 若未来引入第三方库，建议迁移至 Swift Package Manager（SPM），在 `Package.swift` 中声明版本约束并配合 `.gitignore` 忽略 `.build/` 目录。
- 当前无 lockfile、无私有源配置、无依赖更新策略，升级依赖需手动检查兼容性并在 Xcode 中重新链接。