---
kind: dependency_management
name: 依赖管理：纯系统框架的 Xcode 原生项目
category: dependency_management
scope:
    - '**'
source_files:
    - Knowledge.xcodeproj/project.pbxproj
---

本仓库是一个 iOS/macOS SwiftUI 应用，**未使用任何第三方依赖管理系统**。经全面扫描未发现以下文件与配置：`Package.swift`（Swift Package Manager）、`Podfile`/`Cartfile`/Carthage、`go.mod`、`package.json`、`requirements.txt`、`Cargo.toml`、`Gemfile`、`pom.xml`、`build.gradle` 等。项目仅通过 `import Foundation / UIKit / SwiftUI / AVFoundation / Combine / SwiftData` 引入 Apple 平台 SDK，所有“依赖”均为操作系统内置框架，由 Xcode 工程文件 `Knowledge.xcodeproj/project.pbxproj` 直接链接，不存在版本锁定、私有源或 vendoring 策略。

因此，该仓库不具备可归纳的依赖管理体系，本类别不适用。