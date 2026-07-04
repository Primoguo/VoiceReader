// VoiceReader/Views/DocumentListView.swift
import SwiftUI
import SwiftData

struct DocumentListView: View {
    @ObservedObject var speakerVM: SpeakerViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.lastOpenedDate, order: .reverse) private var documents: [Document]
    @State private var showPicker = false
    @State private var alertMsg = ""
    @State private var showAlert = false

    private let extractor = TextExtractionService()

    var body: some View {
        NavigationStack {
            Group {
                if documents.isEmpty {
                    emptyView
                } else {
                    List {
                        ForEach(documents) { doc in
                            DocumentRowView(
                                document: doc,
                                isPlaying: speakerVM.currentDocument?.id == doc.id && speakerVM.state == .playing
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                speakerVM.loadDocument(doc)
                                speakerVM.play()
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { deleteDoc(doc) } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("书库")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showPicker = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showPicker) {
                DocumentPicker { url in importFile(url) }
            }
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) {}
            } message: { Text(alertMsg) }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass").font(.system(size: 60)).foregroundColor(.secondary)
            Text("还没有文档").font(.title2).foregroundColor(.secondary)
            Text("点击右上角 + 导入文档").font(.subheadline).foregroundColor(.secondary)
            Button { showPicker = true } label: {
                Label("导入文档", systemImage: "square.and.arrow.down.fill")
                    .font(.headline).padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color.blue).foregroundColor(.white).clipShape(Capsule())
            }
        }
    }

    private func importFile(_ url: URL) {
        let title = (url.lastPathComponent as NSString).deletingPathExtension
        do {
            let text = try extractor.extractText(from: url)
            let doc = Document(title: title, fileName: url.lastPathComponent, fileType: url.pathExtension.lowercased(),
                               extractedText: text, totalLength: (text as NSString).length)
            modelContext.insert(doc)
            try modelContext.save()
        } catch {
            alertMsg = error.localizedDescription
            showAlert = true
        }
    }

    private func deleteDoc(_ doc: Document) {
        if speakerVM.currentDocument?.id == doc.id { speakerVM.stop() }
        modelContext.delete(doc)
        try? modelContext.save()
    }
}
