---
kind: design
name: 通过 TTSEngine 枚举 + SpeechSynthesizerProtocol 抽象接入 Azure TTS 作为免费在线引擎
source: session
category: adr
---

# 通过 TTSEngine 枚举 + SpeechSynthesizerProtocol 抽象接入 Azure TTS 作为免费在线引擎

_来源：8d8d5f3 → 0a882ac 提交周期内记录的编码计划——内容为规划时意图，实现可能滞后或有出入。_

**状态：** accepted

## 背景
现有 TTS 体系包含 Apple Neural TTS（离线/免费）、Knowledge Voice/CosyVoice（在线/Premium）和传统系统 TTS（离线/兼容），但中文语音质量在离线场景下不够自然，需要引入一个高质量的在线免费方案。

## 决策驱动
- 免费额度可覆盖早期个人用户量
- 与现有多引擎架构保持一致
- 出错时能自动降级到系统 TTS 保证可用性

## 备选方案
- **直接集成 Azure Speech REST API 作为新引擎** — 优点：利用 F0 免费层（50 万字/月），无需自建后端；中文音色丰富（晓晓、云希等 8+ 种）；复用现有 SpeechSynthesizerProtocol 抽象，改动最小
- **自建中转服务器转发 Azure 请求** _（已否决）_ — 优点：可隐藏 API Key、统一配额管理、支持未来多供应商聚合；缺点：额外运维成本；当前免费额度对个人 App 足够，过早引入增加复杂度
- **仅升级 Apple Neural TTS 或继续依赖系统 TTS** _（已否决）_ — 优点：零网络依赖、零第三方密钥；缺点：中文自然度不足，无法达到 Knowledge Voice 的听感水平

## 决策
在 TTSEngine 枚举新增 azureTTS 分支，新建 AzureTTSService 封装 Azure Speech REST API（Ocp-Apim-Subscription-Key 内置 Key），AzureTTSSynthesizer 实现 SpeechSynthesizerProtocol 并复用 CosyVoiceSynthesizer 的分段合成/播放/位置追踪逻辑；SpeakerViewModel.switchEngine 路由到该引擎，错误回调中降级到 systemSynthesizer。

## 影响
短期：客户端直连 Azure，API Key 随包分发，需监控免费额度使用；长期：当用量超出 50 万字符/月时可平滑迁移到 ServerAPIClient 中转模式，无需重构上层引擎选择逻辑。