---
kind: logging_system
name: 基于 print 的轻量级日志输出
category: logging_system
scope:
    - '**'
source_files:
    - Services/ErrorHandler.swift
---

本仓库未引入任何第三方或系统级日志框架（如 os_log、Logger），也未建立统一的日志基础设施。全项目日志输出采用最简方式：在各业务文件中直接调用 `print()` 输出调试信息，并在 `Services/ErrorHandler.swift` 中集中提供两个辅助方法作为“伪日志层”。

- 全局错误处理类 `ErrorHandler` 提供 `handle(_:context:)` 与 `log(_:level:)` 两个入口，内部统一通过 `print` 输出，并附带 emoji 前缀区分级别（🔍 debug / ℹ️ info / ⚠️ warn / ❌ error）。
- `LogLevel` 枚举仅用于在 `ErrorHandler.log` 中选择前缀，并未实现真正的分级过滤或开关控制。
- 除 `ErrorHandler` 外，大量 Service、ViewModel、View 文件仍直接使用裸 `print` 输出，例如 `AudioSessionService`、`TextExtractionService`、`SpeakerViewModel`、`SystemVoiceSelectView` 等，格式不统一、无上下文字段、无结构化字段。
- 没有日志 sink、文件写入、远程上报、采样或脱敏机制；所有输出均直达 Xcode Console。

开发者约定（现状）：
1. 优先使用 `ErrorHandler.shared.handle(_:context:)` 记录异常，以便同时弹出 UI 提示。
2. 需要非错误类日志时可用 `ErrorHandler.shared.log(_:level:)`，但多数代码仍直接 `print`，建议逐步迁移到前者以获得统一前缀。
3. 当前无日志级别开关，无法在生产环境关闭输出，如需生产可考虑后续接入 `os_log` 并通过编译宏控制。