import SwiftUI

struct ChapterSelectorView: View {
    let chapters: [Chapter]
    let currentChapter: Chapter?
    let onSelect: (Chapter) -> Void
    
    @State private var searchText = ""
    @StateObject private var multiLevelManager = MultiLevelChapterManager.shared
    @State private var useMultiLevelView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                
                if useMultiLevelView {
                    multiLevelChapterList
                } else {
                    flatChapterList
                }
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { useMultiLevelView.toggle() }) {
                        Image(systemName: useMultiLevelView ? "list.bullet" : "list.bullet.indent")
                    }
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索章节", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }
    
    private var flatChapterList: some View {
        List {
            ForEach(filteredChapters) { chapter in
                Button(action: { onSelect(chapter) }) {
                    HStack {
                        Text(chapter.title)
                            .foregroundColor(chapter.id == currentChapter?.id ? .blue : .primary)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        if chapter.id == currentChapter?.id {
                            Image(systemName: "book.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    private var multiLevelChapterList: some View {
        List {
            ForEach(filteredMultiLevelChapters) { chapter in
                ChapterSelectorRow(
                    chapter: chapter,
                    isSelected: chapter.originalIndex == currentChapter?.index,
                    onTap: {
                        if let originalChapter = chapters[safe: chapter.originalIndex] {
                            onSelect(originalChapter)
                        }
                    },
                    onToggleExpand: {
                        multiLevelManager.toggleExpand(chapter.id)
                    }
                )
            }
        }
        .listStyle(.plain)
        .onAppear {
            if !chapters.isEmpty {
                let _ = multiLevelManager.parseChapters(from: chapters)
            }
        }
    }
    
    private var filteredChapters: [Chapter] {
        if searchText.isEmpty {
            return chapters
        }
        return chapters.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var filteredMultiLevelChapters: [MultiLevelChapter] {
        let allChapters = multiLevelManager.flattenChapters()
        if searchText.isEmpty {
            return allChapters
        }
        return allChapters.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
}

struct ChapterSelectorRow: View {
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

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
