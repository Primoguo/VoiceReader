// VoiceReader/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var speakerVM = SpeakerViewModel()
    @StateObject private var errorHandler = ErrorHandler.shared

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
        .alert(item: $errorHandler.currentAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("确定")))
        }
    }
}
