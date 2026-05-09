import SwiftUI

struct TableOfContentsView: View {
    @Environment(\.dismiss) var dismiss
    
    let book: Book
    let currentChapterIndex: Int
    let onSelectChapter: (Int) -> Void
    
    @State private var expandedSections: Set<String> = []
    @State private var localCurrentIndex: Int
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var showRefreshAlert = false
    @State private var showEditBook = false
    
    init(book: Book, currentChapterIndex: Int, onSelectChapter: @escaping (Int) -> Void) {
        self.book = book
        self.currentChapterIndex = currentChapterIndex
        self.onSelectChapter = onSelectChapter
        self._localCurrentIndex = State(initialValue: currentChapterIndex)
    }
    
    private var sections: [String] {
        var result: [String] = []
        for chapter in filteredChapters {
            if let section = chapter.section, !result.contains(section) {
                result.append(section)
            }
        }
        return result
    }
    
    private var filteredChapters: [Chapter] {
        if searchText.isEmpty {
            return book.chapters
        }
        return book.chapters.filter {
            $0.title.lowercased().contains(searchText.lowercased())
        }
    }
    
    private func chaptersInSection(_ section: String?) -> [(index: Int, chapter: Chapter)] {
        return book.chapters.enumerated().compactMap { idx, chapter in
            if searchText.isEmpty || chapter.title.lowercased().contains(searchText.lowercased()) {
                if section == nil && chapter.section == nil {
                    return (idx, chapter)
                } else if let section = section, chapter.section == section {
                    return (idx, chapter)
                }
            }
            return nil
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(book.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    showRefreshAlert = true
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.white)
                }
                
                Button(action: {
                    withAnimation {
                        showSearch.toggle()
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if showSearch {
                TextField("搜索", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .foregroundColor(.white)
                    .accentColor(Color(hex: "8BC34A")!)
            }
            
            Text("可用左滑手势对项进行操作")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            ScrollView {
                VStack(spacing: 0) {
                    if searchText.isEmpty {
                        let noSectionChapters = chaptersInSection(nil)
                        ForEach(noSectionChapters, id: \.chapter.id) { index, chapter in
                            chapterRow(chapter: chapter, index: index, isSectionChapter: false)
                        }
                        
                        ForEach(sections, id: \.self) { section in
                            VStack(spacing: 0) {
                                Button(action: {
                                    withAnimation {
                                        if expandedSections.contains(section) {
                                            expandedSections.remove(section)
                                        } else {
                                            expandedSections.insert(section)
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: expandedSections.contains(section) ? "chevron.down" : "chevron.right")
                                            .foregroundColor(.white)
                                            .font(.caption)
                                        
                                        Text(section)
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        let sectionChapters = chaptersInSection(section)
                                        Text("\(sectionChapters.count)")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                
                                if expandedSections.contains(section) {
                                    let sectionChapters = chaptersInSection(section)
                                    ForEach(sectionChapters, id: \.chapter.id) { index, chapter in
                                        chapterRow(chapter: chapter, index: index, isSectionChapter: true)
                                    }
                                }
                            }
                        }
                    } else {
                        if filteredChapters.isEmpty {
                            Text("未找到匹配的章节")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.vertical, 24)
                        } else {
                            ForEach(filteredChapters.indices, id: \.self) { idx in
                                let chapter = filteredChapters[idx]
                                if let originalIndex = book.chapters.firstIndex(where: { $0.id == chapter.id }) {
                                    chapterRow(chapter: chapter, index: originalIndex, isSectionChapter: false)
                                }
                            }
                        }
                    }
                }
            }
            .background(Color(hex: "1B5E20")!.opacity(0.5))
            
            HStack(spacing: 16) {
                if let currentChapter = book.chapters[safe: localCurrentIndex] {
                    Text("\(currentChapter.title) (\(localCurrentIndex + 1)/\(book.chapters.count))")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Text("序号")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "1B5E20")!)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            HStack(spacing: 0) {
                Button(action: {}) {
                    VStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .foregroundColor(Color(hex: "8BC34A")!)
                        
                        Text("目录")
                            .font(.caption)
                            .foregroundColor(Color(hex: "8BC34A")!)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                Button(action: {}) {
                    VStack(spacing: 4) {
                        Image(systemName: "bookmark")
                            .foregroundColor(.white)
                        
                        Text("书签")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                Button(action: {}) {
                    VStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .foregroundColor(.white)
                        
                        Text("笔记")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .background(Color(hex: "1B5E20")!)
        }
        .background(Color(hex: "1B5E20")!.opacity(0.95))
        .presentationDetents([.large])
        .alert(isPresented: $showRefreshAlert) {
            Alert(
                title: Text("提示"),
                message: Text("重新从原文件中加载所有数据，将覆盖当前所有被修改过的内容"),
                primaryButton: .destructive(Text("重新解析")) {
                    showEditBook = true
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
        .fullScreenCover(isPresented: $showEditBook) {
            EditBookView(book: book)
        }
    }
    
    private func chapterRow(chapter: Chapter, index: Int, isSectionChapter: Bool) -> some View {
        Button(action: {
            localCurrentIndex = index
            onSelectChapter(index)
            dismiss()
        }) {
            HStack {
                if isSectionChapter {
                    Text("  ")
                        .font(.subheadline)
                }
                
                Text(chapter.title)
                    .font(.subheadline)
                    .foregroundColor(localCurrentIndex == index ? Color(hex: "8BC34A")! : .white)
                    .lineLimit(1)
                
                Spacer()
                
                if chapter.wordCount > 0 {
                    Text("\(chapter.wordCount)")
                        .font(.caption)
                        .foregroundColor(localCurrentIndex == index ? Color(hex: "8BC34A")! : .white.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .swipeActions(edge: .trailing) {
            Button("分级") {
                print("分级 \(chapter.title)")
            }
            .tint(.purple)
            
            Button("改名") {
                print("改名 \(chapter.title)")
            }
            .tint(.blue)
            
            Button("更多") {
                print("更多 \(chapter.title)")
            }
            .tint(.orange)
            
            Button("删除") {
                print("删除 \(chapter.title)")
            }
            .tint(.red)
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}