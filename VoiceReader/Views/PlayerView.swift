// VoiceReader/Views/PlayerView.swift
import SwiftUI

struct PlayerView: View {
    @ObservedObject var speakerVM: SpeakerViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let doc = speakerVM.currentDocument {
                    VStack(spacing: 24) {
                        Spacer()
                        // 封面
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(colors: [.blue.opacity(0.8), .purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 180, height: 180).shadow(radius: 10)
                            VStack(spacing: 8) {
                                Image(systemName: icon(doc.fileType)).font(.system(size: 40)).foregroundColor(.white)
                                Text(doc.fileType.uppercased()).font(.caption).fontWeight(.bold).foregroundColor(.white.opacity(0.8))
                            }
                        }
                        // 信息
                        VStack(spacing: 6) {
                            Text(doc.title).font(.title2).fontWeight(.bold).lineLimit(2).multilineTextAlignment(.center)
                            Text("\(doc.fileType.uppercased()) · \(formatLen(doc.totalLength))").font(.subheadline).foregroundColor(.secondary)
                        }.padding(.horizontal, 32)
                        // 进度条
                        VStack(spacing: 8) {
                            Slider(value: Binding(get: { speakerVM.progress }, set: { speakerVM.seekTo(progress: $0) })).tint(.blue)
                            HStack {
                                Text(speakerVM.currentPositionText).font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Text(formatDuration(doc.totalLength)).font(.caption).foregroundColor(.secondary)
                            }
                        }.padding(.horizontal, 32)
                        // 控制按钮
                        PlayerControlsView(speakerVM: speakerVM).padding(.horizontal, 32)
                        Spacer()
                    }
                } else {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "headphones").font(.system(size: 60)).foregroundColor(.secondary)
                        Text("暂无播放内容").font(.title2).foregroundColor(.secondary)
                        Text("在书库中选择一篇文档开始朗读").font(.subheadline).foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .navigationTitle("正在播放")
        }
    }

    private func icon(_ t: String) -> String {
        switch t { case "pdf": return "doc.richtext"; case "docx": return "doc.text"; case "xlsx": return "tablecells"; case "pptx": return "chart.bar.doc.horizontal"; default: return "doc" }
    }
    private func formatLen(_ len: Int) -> String {
        len >= 10000 ? String(format: "%.1f万字", Double(len) / 10000.0) : "\(len)字"
    }
    private func formatDuration(_ len: Int) -> String {
        let sec = len / 3; return String(format: "%02d:%02d", sec / 60, sec % 60)
    }
}
