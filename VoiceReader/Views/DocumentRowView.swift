// VoiceReader/Views/DocumentRowView.swift
import SwiftUI

struct DocumentRowView: View {
    let document: Document
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20)).foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.system(size: 16, weight: .medium)).lineLimit(1)
                    .foregroundColor(isPlaying ? .blue : .primary)
                HStack(spacing: 8) {
                    Text(document.fileType.uppercased())
                        .font(.caption2).fontWeight(.medium)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12)).clipShape(Capsule())
                    Text(formatLen(document.totalLength)).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            if document.progress > 0 {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(document.progress * 100))%").font(.caption).foregroundColor(.secondary)
                    ProgressView(value: document.progress).frame(width: 40).tint(.blue)
                }
            }
            if isPlaying {
                Image(systemName: "waveform").font(.title3).foregroundColor(.blue)
                    .symbolEffect(.variableColor.iterative)
            }
        }
        .padding(.vertical, 6)
    }

    private var icon: String {
        switch document.fileType {
        case "pdf": return "doc.richtext"
        case "docx": return "doc.text"
        case "xlsx": return "tablecells"
        case "pptx": return "chart.bar.doc.horizontal"
        default: return "doc"
        }
    }

    private var iconColor: Color {
        switch document.fileType {
        case "pdf": return .red
        case "docx": return .blue
        case "xlsx": return .green
        case "pptx": return .orange
        default: return .gray
        }
    }

    private func formatLen(_ len: Int) -> String {
        if len >= 10000 { return String(format: "%.1f万字", Double(len) / 10000.0) }
        else if len >= 1000 { return String(format: "%.1f千字", Double(len) / 1000.0) }
        return "\(len)字"
    }
}
