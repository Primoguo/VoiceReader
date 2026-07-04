// VoiceReader/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var speakerVM = SpeakerViewModel()

    var body: some View {
        TabView {
            DocumentListView(speakerVM: speakerVM)
                .tabItem { Label("书库", systemImage: "books.vertical.fill") }
            PlayerView(speakerVM: speakerVM)
                .tabItem { Label("正在播放", systemImage: "headphones") }
            SettingsView(speakerVM: speakerVM)
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .tint(.blue)
    }
}
