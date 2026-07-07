// Knowledge/Services/SystemVoiceManager.swift
import Foundation
import AVFoundation

/// 系统语音管理器 - 提供 iOS 17+ Neural TTS 音色选择
@MainActor
final class SystemVoiceManager {
    
    static let shared = SystemVoiceManager()
    
    /// 获取所有可用的中文 Neural 音色（iOS 17+）
    var availableChineseVoices: [AVSpeechSynthesisVoice] {
        guard #available(iOS 17.0, *) else { return [] }
        
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { voice in
                // 过滤中文语音（包括普通话和粤语）
                let isChinese = voice.language.hasPrefix("zh-") || voice.language.hasPrefix("cmn-")
                // 优先选择 Neural TTS（eloquence 系列或 super-compact）
                let isNeural = voice.identifier.contains("eloquence") || voice.identifier.contains("super-compact")
                return isChinese && isNeural
            }
            .sorted { $0.name < $1.name }
    }
    
    /// 获取所有可用的英文 Neural 音色（iOS 17+）
    var availableEnglishVoices: [AVSpeechSynthesisVoice] {
        guard #available(iOS 17.0, *) else { return [] }
        
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en-") }
            .sorted { $0.name < $1.name }
    }
    
    /// 根据语言代码获取推荐音色
    func recommendedVoice(for language: String) -> AVSpeechSynthesisVoice? {
        guard #available(iOS 17.0, *) else {
            return AVSpeechSynthesisVoice(language: language)
        }
        
        // 优先选择 Neural TTS 音色（eloquence 系列）
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == language }
        
        // 第一优先级：eloquence 系列（真正的 Neural TTS）
        if let neural = voices.first(where: { $0.identifier.contains("eloquence") }) {
            return neural
        }
        
        // 第二优先级：super-compact 系列
        if let compact = voices.first(where: { $0.identifier.contains("super-compact") }) {
            return compact
        }
        
        // 最后：任意可用音色
        return voices.first ?? AVSpeechSynthesisVoice(language: language)
    }
    
    /// 检查指定 identifier 是否为 Neural 音色
    func isNeuralVoice(identifier: String) -> Bool {
        guard #available(iOS 17.0, *) else { return false }
        
        // iOS 17+ 的 Neural TTS 通过 identifier 识别：
        // - com.apple.eloquence.* （主要 Neural TTS 系列）
        // - com.apple.voice.super-compact.* （紧凑版 Neural TTS）
        return identifier.contains("eloquence") || identifier.contains("super-compact")
    }
}

/// 系统音色信息（用于 UI 展示）
struct SystemVoiceInfo: Identifiable, Equatable {
    let id: String          // voice.identifier
    let name: String        // 显示名称
    let language: String    // 语言代码
    let quality: String     // 音质描述
    let isNeural: Bool      // 是否为 Neural 音色
    
    init(voice: AVSpeechSynthesisVoice) {
        self.id = voice.identifier
        self.name = voice.name
        self.language = voice.language
        
        // iOS 17+ 的 Neural TTS 通过 identifier 识别，而非 quality 属性
        // quality 属性在 iOS 17+ 中始终返回 .default，即使对于 Neural TTS
        if #available(iOS 17.0, *) {
            self.isNeural = voice.identifier.contains("eloquence") || voice.identifier.contains("super-compact")
            
            // 根据是否为 Neural TTS 显示不同的质量标签
            if self.isNeural {
                if voice.identifier.contains("super-compact") {
                    self.quality = "Neural（紧凑版）"
                } else {
                    self.quality = "Neural（增强版）"
                }
            } else {
                self.quality = "标准版"
            }
        } else {
            self.isNeural = false
            self.quality = "标准版"
        }
    }
}
