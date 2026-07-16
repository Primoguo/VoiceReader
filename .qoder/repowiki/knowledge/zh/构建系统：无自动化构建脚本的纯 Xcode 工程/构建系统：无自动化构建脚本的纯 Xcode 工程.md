---
kind: build_system
name: 构建系统：无自动化构建脚本的纯 Xcode 工程
category: build_system
scope:
    - '**'
source_files:
    - README.md
    - PRD.md
---

本仓库是一个 iOS SwiftUI 应用（Knowledge / 挠荔枝），**未包含任何自动化构建、打包或 CI 配置**。项目采用最简化的本地开发模式，所有构建与发布均依赖开发者在 Xcode 中手动操作。

## 现状概览
- **无 Makefile / build.sh / Dockerfile / Jenkinsfile**：不存在任何命令行构建脚本
- **无 .xcodeproj / .xcworkspace**：没有 Xcode 项目文件，需通过 `swift package generate-xcodeproj` 生成或在 Xcode 中手动创建项目
- **无 Swift Package Manager 清单**：未发现 `Package.swift`，说明当前代码以目录结构形式组织，尚未声明为 SPM 包
- **无第三方依赖管理**：README 明确「无第三方依赖（纯 Swift + 系统框架）」，因此无需 CocoaPods、Carthage 等工具
- **无 CI/CD 配置**：未发现 `.github/workflows`、`.gitlab-ci.yml`、`fastlane` 等持续集成或自动发布流程
- **无容器化**：无 Dockerfile，应用为纯 iOS 客户端，不涉及服务端部署

## 本地构建方式
根据 README 和 PRD 中的要求，开发者需在本地完成以下步骤：
1. 使用 Xcode 15+ 打开项目（需先通过 `swift package generate-xcodeproj` 生成项目文件或手动创建）
2. 在 Signing & Capabilities 中启用 Background Modes → Audio
3. 替换 `ServerAPIClient.baseURL` 为实际服务器地址（阿里云中转 API）
4. 在 App Store Connect 中配置 IAP 产品并替换 `SubscriptionManager.productIDs`
5. 直接通过 Xcode Build & Run 编译到真机或模拟器

## 版本管理策略
版本信息仅维护在 `PRD.md` 顶部的元数据区域（当前 V1.4.0），采用文档驱动的版本记录方式，而非通过构建脚本自动生成版本号。每次发版需手动更新 PRD 中的版本号与修订记录表格。

## 设计决策与影响
- **零依赖策略**：刻意避免引入第三方库以降低维护成本，但同时也意味着无法利用成熟的构建生态（如 Fastlane 自动化签名、TestFlight 上传等）
- **Xcode 原生工作流**：完全依赖 Xcode IDE 进行构建、调试、签名与分发，适合单人或小团队开发，但在跨平台协作和自动化方面存在局限
- **iOS 17+ 最低版本**：限制了可使用的系统 API 范围，但也简化了兼容性处理

## 建议改进方向
若后续需要增强构建能力，可考虑：
- 添加 `Package.swift` 将核心模块（Services、Models）声明为 SPM 包，便于单元测试与复用
- 引入 Fastlane 自动化签名、构建与 TestFlight 分发流程
- 添加 GitHub Actions 用于基础编译检查与静态分析
- 通过 Xcode Cloud 实现云端构建与测试