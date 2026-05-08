import SwiftUI

struct LazyChapterListView: View {
    @ObservedObject var book: LazyBookProtocol
    @Binding var currentIndex: Int
    let onSelect: ((Int) -> Void)? = nil
    
    @Environment(\.dismiss) var dismiss
    @State private var searchText: String = ""
    @State private var chapters: [Int: String] = [:]
    @State private var multiLevelChapters: [MultiLevelChapter] = []
    @State private var isLoading: Bool = true
    @State private var useMultiLevelView: Bool = false
    @StateObject private var multiLevelManager = MultiLevelChapterManager.shared
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("加载目录...")
                } else {
                    List {
                        if useMultiLevelView {
                            ForEach(multiLevelChapters) { chapter in
                                LazyChapterRow(
                                    chapter: chapter,
                                    isSelected: chapter.originalIndex == currentIndex,
                                    onTap: {
                                        currentIndex = chapter.originalIndex
                                        onSelect?(chapter.originalIndex)
                                        dismiss()
                                    },
                                    onToggleExpand: {
                                        multiLevelManager.toggleExpand(chapter.id)
                                        multiLevelChapters = multiLevelManager.flattenChapters()
                                    }
                                )
                            }
                        } else {
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
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { useMultiLevelView.toggle() }) {
                        Image(systemName: useMultiLevelView ? "list.bullet" : "list.bullet.indent")
                    }
                }
                
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
        
        let chapterTitles = (0..<min(book.chaptersCount, 100)).map { index -> String in
            if let chapter = try? await book.loadChapter(at: index) {
                return chapter.title
            }
            return "第\(index + 1)章"
        }
        
        multiLevelChapters = multiLevelManager.parseChaptersWithHeaderDetection(chapterTitles)
        
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

struct LazyChapterRow: View {
    let chapter: MultiLevelChapter
    let isSelected: Bool
    let onTap: () -> Void
    let onToggleExpand: () -> Void
    
    var body: some View {
        Button(action: {
            if chapter.hasChildren {
                onToggleExpand()
            } else {
                onTap()
            }
        }) {
            HStack(spacing: 8) {
                if chapter.hasChildren {
                    Image(systemName: chapter.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                } else {
                    Spacer()
                        .frame(width: 16)
                }
                
                Text(chapter.title)
                    .font(.system(size: chapter.level == 0 ? 15 : 14))
                    .fontWeight(chapter.level == 0 ? .medium : .regular)
                    .foregroundColor(isSelected ? .blue : .primary)
                    .lineLimit(2)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "book.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.leading, CGFloat(chapter.level) * 16)
            .padding(.vertical, 4)
        }
    }
}
