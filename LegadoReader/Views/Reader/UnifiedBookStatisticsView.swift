import SwiftUI

struct UnifiedBookStatisticsView: View {
    let bookId: String
    @ObservedObject var book: LazyBookProtocol
    
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
            
            if book.chaptersCount > 1 {
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
                chapterTitles: nil
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
                Text("正在统计 \(book.bookType.rawValue) 格式...")
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
                Text("点击统计 \(book.bookType.rawValue) 总字数")
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
        
        let result = await book.calculateStatistics { progress in
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


