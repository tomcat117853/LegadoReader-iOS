import SwiftUI

struct LazyChapterListView: View {
    @ObservedObject var book: LazyBookProtocol
    @Binding var currentIndex: Int
    let onSelect: ((Int) -> Void)? = nil
    
    @Environment(\.dismiss) var dismiss
    @State private var searchText: String = ""
    @State private var chapters: [Int: String] = [:]
    @State private var isLoading: Bool = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("加载目录...")
                } else {
                    List {
                        ForEach(sortedChapterIndices, id: \.self) { index in
                            Button(action: {
                                currentIndex = index
                                onSelect?(index)
                                dismiss()
                            }) {
                                HStack {
                                    Text(chapters[index] ?? "第\(index + 1)章")
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                    
                                    Spacer()
                                    
                                    if index == currentIndex {
                                        Image(systemName: "book.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索章节")
            .task {
                await loadAllChapters()
            }
        }
    }
    
    private var sortedChapterIndices: [Int] {
        chapters.keys.sorted()
    }
    
    private var filteredChapters: [(index: Int, title: String)] {
        let allChapters = chapters.map { (index: $0.key, title: $0.value) }
        if searchText.isEmpty {
            return allChapters.sorted { $0.index < $1.index }
        }
        return allChapters.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    private func loadAllChapters() async {
        isLoading = true
        for i in 0..<min(book.chaptersCount, 100) {
            if let chapter = try? await book.loadChapter(at: i) {
                await MainActor.run {
                    self.chapters[i] = chapter.title
                }
            }
        }
        await MainActor.run {
            self.isLoading = false
        }
    }
}
