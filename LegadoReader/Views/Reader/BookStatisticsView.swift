import SwiftUI

struct BookStatisticsView: View {
    let bookId: String
    let book: LazyEPUBBook
    
    @State private var statistics: BookStatistics?
    @State private var isCalculating: Bool = false
    @State private var calculationProgress: Double = 0
    @State private var showingDetail: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            if let stats = statistics {
                statisticsSummary(stats)
            } else if isCalculating {
                calculatingView
            } else {
                startCalculationButton
            }
        }
        .padding()
    }
    
    private func statisticsSummary(_ stats: BookStatistics) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                statCard(
                    title: "总字数",
                    value: stats.formattedTotalCharacters,
                    icon: "character.cursor.ibeam"
                )
                
                statCard(
                    title: "总词数",
                    value: stats.formattedTotalWords,
                    icon: "text.word.spacing"
                )
            }
            
            HStack(spacing: 20) {
                statCard(
                    title: "章节数",
                    value: "\(stats.totalChapters)",
                    icon: "book.pages"
                )
                
                statCard(
                    title: "平均章节字数",
                    value: stats.totalChapters > 0 ? "\(stats.totalCharacters / stats.totalChapters)" : "0",
                    icon: "chart.bar"
                )
            }
            
            Button(action: {
                showingDetail = true
            }) {
                HStack {
                    Image(systemName: "list.bullet")
                    Text("查看各章节统计")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(10)
            }
            
            Button(action: {
                Task {
                    await recalculateStatistics()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("重新统计")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.1))
                .foregroundColor(.orange)
                .cornerRadius(10)
            }
        }
        .sheet(isPresented: $showingDetail) {
            ChapterStatisticsDetailView(
                statistics: statistics,
                chapterTitles: book.chapters.map { $0.title }
            )
        }
    }
    
    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var calculatingView: some View {
        VStack(spacing: 16) {
            ProgressView(value: calculationProgress) {
                Text("正在统计...")
                    .font(.headline)
            }
            .progressViewStyle(.linear)
            
            Text("\(Int(calculationProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("取消") {
                isCalculating = false
            }
            .foregroundColor(.red)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var startCalculationButton: some View {
        Button(action: {
            Task {
                await recalculateStatistics()
            }
        }) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                Text("点击统计总字数")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
    
    private func recalculateStatistics() async {
        isCalculating = true
        calculationProgress = 0
        
        let result = await EPUBLazyStatisticsCalculator.shared.calculateStatistics(
            for: bookId,
            book: book
        ) { progress in
            Task { @MainActor in
                self.calculationProgress = progress
            }
        }
        
        await MainActor.run {
            self.statistics = result
            self.isCalculating = false
        }
    }
}

struct ChapterStatisticsDetailView: View {
    let statistics: BookStatistics?
    let chapterTitles: [String]
    
    @Environment(\.dismiss) var dismiss
    
    var sortedChapters: [(index: Int, wordCount: Int, title: String)] {
        guard let stats = statistics else { return [] }
        return stats.chapterWordCounts
            .sorted { $0.key < $1.key }
            .map { (index: $0.key, wordCount: $0.value, title: chapterTitles.indices.contains($0.key) ? chapterTitles[$0.key] : "章节 \($0.key + 1)") }
    }
    
    var body: some View {
        NavigationView {
            List {
                if let stats = statistics {
                    Section {
                        HStack {
                            Text("总字数")
                            Spacer()
                            Text(stats.formattedTotalCharacters)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("总词数")
                            Spacer()
                            Text(stats.formattedTotalWords)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("章节数")
                            Spacer()
                            Text("\(stats.totalChapters)")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("统计概览")
                    }
                }
                
                Section {
                    ForEach(sortedChapters, id: \.index) { chapter in
                        HStack {
                            Text("第\(chapter.index + 1)章")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 50)
                            
                            Text(chapter.title)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(chapter.wordCount)字")
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("各章节统计")
                }
            }
            .navigationTitle("章节统计详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LazyBookInfoCard: View {
    let book: LazyEPUBBook
    let bookId: String
    
    @State private var isStatisticsExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.metadata.title)
                        .font(.headline)
                    
                    Text(book.metadata.author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("章节: \(book.chapters.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("语言: \(book.metadata.language)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            DisclosureGroup("字数统计", isExpanded: $isStatisticsExpanded) {
                BookStatisticsView(bookId: bookId, book: book)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct LazyBookListItem: View {
    let book: LazyEPUBBook
    let bookId: String
    let onRead: () -> Void
    let onStatistics: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if let coverData = book.coverImage,
               let uiImage = UIImage(data: coverData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 80)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 80)
                    .overlay(
                        Image(systemName: "book.closed")
                            .foregroundColor(.secondary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.metadata.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(book.metadata.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 16) {
                    Label("\(book.chapters.count)章", systemImage: "book.pages")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Label(book.metadata.language, systemImage: "globe")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Button(action: onRead) {
                    Image(systemName: "book")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                
                Button(action: onStatistics) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
