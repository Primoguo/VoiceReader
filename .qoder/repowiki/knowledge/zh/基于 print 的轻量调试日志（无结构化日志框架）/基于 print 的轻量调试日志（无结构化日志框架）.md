---
kind: logging_system
name: 基于 print 的轻量调试日志（无结构化日志框架）
category: logging_system
scope:
    - '**'
source_files:
    - Services/ErrorHandler.swift
---

本仓库未引入任何第三方或系统级日志框架（如 os.log、Logger、SwiftyBeaver、CocoaLumberjack 等），也未发现 `log/`、`logging/` 等专用目录。整个应用的输出完全依赖 Swift 标准库的 `print()`，属于最基础的调试输出方式。

具体表现：
- 全局错误处理集中在 `Services/ErrorHandler.swift`，提供 `handle(_:context:)` 和 `log(_:level:)` 两个方法，内部统一通过 `print` 输出，并附带 emoji 前缀区分级别（🔍 debug / ℹ️ info / ⚠️ warn / ❌ error）。该文件还定义了本地 `LogLevel` 枚举，但并未与任何日志后端集成。
- 业务代码中大量散落 `print` 调用，例如 `AudioSessionService`、`TextExtractionService`、`SpeakerViewModel`、`EdgeVoiceSelectView` 等，用于记录音频会话配置、OCR 进度、TTS 引擎切换、音色加载等信息。
- 所有日志均直接输出到 Xcode 控制台，不存在分级开关、结构化字段、持久化存储或远程上报能力；也没有统一的日志初始化入口。

结论：该项目目前不具备可配置的日志系统，仅以 `print` 作为开发期调试手段，不符合生产环境日志规范。若需升级，建议引入 `os.Logger` 或第三方库，并将 `ErrorHandler.log` 作为统一入口进行替换。
