import SwiftUI

struct TableOfContentsView: View {
    @Environment(\.dismiss) var dismiss
    
    let bookName: String
    let chapters: [Chapter]
    let currentChapterIndex: Int
    let onSelectChapter: (Int) -> Void
    
    @State private var expandedSections: Set<String> = []
    @State private var localCurrentIndex: Int
    
    init(bookName: String, chapters: [Chapter], currentChapterIndex: Int, onSelectChapter: @escaping (Int) -> Void) {
        self.bookName = bookName
        self.chapters = chapters
        self.currentChapterIndex = currentChapterIndex
        self.onSelectChapter = onSelectChapter
        self._localCurrentIndex = State(initialValue: currentChapterIndex)
    }
    
    private var sections: [String] {
        var result: [String] = []
        for chapter in chapters {
            if let section = chapter.section, !result.contains(section) {
                result.append(section)
            }
        }
        return result
    }
    
    private func chaptersInSection(_ section: String?) -> [Chapter] {
        return chapters.enumerated().compactMap { index, chapter in
            if section == nil && chapter.section == nil {
                return (index, chapter)
            } else if let section = section, chapter.section == section {
                return (index, chapter)
            }
            return nil
        }.map { ($0.offset, $0.element) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(bookName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.white)
                }
                
                Button(action: {}) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Text("可用左滑手势对项进行操作")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            ScrollView {
                VStack(spacing: 0) {
                    let noSectionChapters = chaptersInSection(nil)
                    ForEach(noSectionChapters, id: \.element.id) { index, chapter in
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
                                ForEach(sectionChapters, id: \.element.id) { index, chapter in
                                    chapterRow(chapter: chapter, index: index, isSectionChapter: true)
                                }
                            }
                        }
                    }
                }
            }
            .background(Color(hex: "1B5E20")!.opacity(0.5))
            
            HStack(spacing: 16) {
                if let currentChapter = chapters[safe: localCurrentIndex] {
                    Text("\(currentChapter.title) (\(localCurrentIndex + 1)/\(chapters.count))")
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
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct TableOfContentsView_Previews: PreviewProvider {
    static var previews: some View {
        TableOfContentsView(
            bookName: "大明春色",
            chapters: [
                Chapter(id: "1", title: "扉页", url: "", content: "", section: nil, wordCount: 0),
                Chapter(id: "2", title: "制作信息", url: "", content: "", section: nil, wordCount: 92),
                Chapter(id: "3", title: "卷一", url: "", content: "", section: nil, wordCount: 2),
                Chapter(id: "4", title: "第一章 洪公子", url: "", content: "", section: "卷一", wordCount: 2542),
                Chapter(id: "5", title: "第二章 想再听弹奏", url: "", content: "", section: "卷一", wordCount: 2579),
            ],
            currentChapterIndex: 3,
            onSelectChapter: { index in
                print("选择章节: \(index)")
            }
        )
    }
}