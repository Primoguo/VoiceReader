// VoiceReader/Models/VoiceConfig.swift
import Foundation

struct VoiceConfig: Equatable, Codable {
    var rate: Float = 0.5
    var pitchMultiplier: Float = 1.0
    var volume: Float = 1.0
    var language: String = "zh-CN"
    var voiceIdentifier: String? = nil

    static let defaultConfig = VoiceConfig()
}
