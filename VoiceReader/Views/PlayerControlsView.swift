// VoiceReader/Views/PlayerControlsView.swift
import SwiftUI

struct PlayerControlsView: View {
    @ObservedObject var speakerVM: SpeakerViewModel

    var body: some View {
        HStack(spacing: 32) {
            ControlButton(icon: "gobackward.15", size: .small) { speakerVM.skipBackward() }
            ControlButton(icon: playIcon, size: .large) { speakerVM.togglePlayPause() }
            ControlButton(icon: "goforward.30", size: .small) { speakerVM.skipForward() }
        }
    }

    private var playIcon: String {
        speakerVM.state == .playing ? "pause.fill" : "play.fill"
    }
}

private struct ControlButton: View {
    enum Size { case small, large }
    let icon: String; let size: Size; let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size == .large ? 28 : 22))
                .foregroundColor(.primary)
                .frame(width: size == .large ? 64 : 40, height: size == .large ? 64 : 40)
                .background(size == .large ? Circle().fill(Color.blue.opacity(0.12)) : Circle().fill(Color.clear))
        }
    }
}
