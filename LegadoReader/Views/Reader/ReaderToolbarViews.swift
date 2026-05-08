import SwiftUI

struct ReaderTopBar: View {
    let bookName: String
    let chapterTitle: String
    let onBack: () -> Void
    let onShowChapters: () -> Void
    let onShowSettings: () -> Void
    let onSelectSource: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .foregroundColor(.white)
                    .font(.title)
            }
            .padding(.leading, 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(bookName)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(chapterTitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(.leading, 8)
            
            Spacer()
            
            Button(action: onShowChapters) {
                Image(systemName: "list.bullet")
                    .foregroundColor(.white)
                    .font(.title)
            }
            .padding(.trailing, 12)
            
            Button(action: onSelectSource) {
                Image(systemName: "arrow.left.right")
                    .foregroundColor(.white)
                    .font(.title)
            }
            .padding(.trailing, 12)
            
            Button(action: onShowSettings) {
                Image(systemName: "ellipsis")
                    .foregroundColor(.white)
                    .font(.title)
            }
            .padding(.trailing, 12)
        }
        .padding(.vertical, 16)
    }
}

struct ReaderBottomBar: View {
    let currentChapter: Chapter?
    let totalChapters: Int
    let currentIndex: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onAudioBook: () -> Void
    let onAutoScroll: () -> Void
    let onShowChapters: () -> Void
    let onCache: () -> Void
    let onPageTurn: () -> Void
    let onSettings: () -> Void
    let progress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onPrevious) {
                    Text("上一章")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(20)
                }
                
                Spacer()
                
                Slider(value: .constant(progress), in: 0...1)
                    .accentColor(.white)
                    .padding(.horizontal, 16)
                
                Spacer()
                
                Button(action: onNext) {
                    Text("下一章")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(20)
                }
            }
            
            HStack(spacing: 0) {
                Button(action: onShowChapters) {
                    VStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.title)
                            .foregroundColor(.white)
                        
                        Text("目录")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                Button(action: onCache) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.title)
                            .foregroundColor(.white)
                        
                        Text("缓存")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                Button(action: onPageTurn) {
                    VStack(spacing: 4) {
                        Image(systemName: "book.open")
                            .font(.title)
                            .foregroundColor(.white)
                        
                        Text("翻页")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                Button(action: onSettings) {
                    VStack(spacing: 4) {
                        Image(systemName: "textformat")
                            .font(.title)
                            .foregroundColor(.white)
                        
                        Text("设置")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
    }
}

struct BookSourceSelectorView: View {
    @Environment(\.dismiss) var dismiss
    let bookName: String
    @State private var searchText = ""
    @State private var selectedSourceId: String?
    
    struct BookSourceItem: Identifiable {
        let id: String
        let name: String
        let chapterCount: Int
        let updateTime: String
        let speed: Int
        let isCurrent: Bool
        let isFailed: Bool
    }
    
    @State private var sources: [BookSourceItem] = [
        BookSourceItem(id: "1", name: "请稍后尝试左滑刷新", chapterCount: 1527, updateTime: "源登陆再搜", speed: 0, isCurrent: true, isFailed: true),
        BookSourceItem(id: "2", name: "10月前更新 第1315章 开幕，混淆视听的正统献礼片", chapterCount: 2004, updateTime: "值得のwhzh", speed: 2515, isCurrent: false, isFailed: false),
        BookSourceItem(id: "3", name: "3个星期前更新 完本感言", chapterCount: 1723, updateTime: "猫眼API叁", speed: 1231, isCurrent: false, isFailed: false),
        BookSourceItem(id: "4", name: "1月前更新 完本感言", chapterCount: 1723, updateTime: "笔趣bi-api", speed: 1429, isCurrent: false, isFailed: false),
        BookSourceItem(id: "5", name: "3个星期前更新 完本感言", chapterCount: 1723, updateTime: "猫眼API壹", speed: 2125, isCurrent: false, isFailed: false),
        BookSourceItem(id: "6", name: "完本感言", chapterCount: 1631, updateTime: "Rmy江南小说网", speed: 1845, isCurrent: false, isFailed: false),
        BookSourceItem(id: "7", name: "10月前更新 完本感言", chapterCount: 1617, updateTime: "值得阅读-多来源", speed: 20960, isCurrent: false, isFailed: false),
        BookSourceItem(id: "8", name: "2月前更新 第1490章 九月尽；与有荣焉……", chapterCount: 1522, updateTime: "笔趣api", speed: 2416, isCurrent: false, isFailed: false),
    ]
    
    var filteredSources: [BookSourceItem] {
        if searchText.isEmpty {
            return sources
        }
        return sources.filter {
            $0.name.lowercased().contains(searchText.lowercased()) ||
            $0.updateTime.lowercased().contains(searchText.lowercased())
        }
    }
    
    var currentSource: BookSourceItem? {
        sources.first { $0.isCurrent }
    }
    
    var failedSources: [BookSourceItem] {
        sources.filter { $0.isFailed }
    }
    
    var availableSources: [BookSourceItem] {
        sources.filter { !$0.isFailed && !$0.isCurrent }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("过滤 \(bookName) 书源 (输入 dyn 显示动态分析源)", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                List {
                    if let current = currentSource {
                        Section(header: Text("当前使用来源")) {
                            sourceRow(current)
                        }
                    }
                    
                    if !failedSources.isEmpty {
                        Section(header: Text("失效或暂无数据")) {
                            ForEach(failedSources) { source in
                                sourceRow(source)
                            }
                        }
                    }
                    
                    if !availableSources.isEmpty {
                        Section(header: Text("其它可用来源: \(availableSources.count)")) {
                            ForEach(availableSources) { source in
                                sourceRow(source)
                            }
                        }
                    }
                }
                .listStyle(.grouped)
            }
            .navigationTitle("选择来源 (\(sources.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    private func sourceRow(_ source: BookSourceItem) -> some View {
        HStack {
            Image(systemName: source.isFailed ? "leaf" : "circle.fill")
                .foregroundColor(source.isFailed ? .green : .secondary)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(source.name)
                    .font(.body)
                    .lineLimit(2)
                
                HStack(spacing: 16) {
                    Text("来自: \(source.updateTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("(\(source.chapterCount)章)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !source.isFailed {
                Text("\(source.speed)毫秒")
                    .font(.caption)
                    .foregroundColor(source.speed < 2000 ? .green : (source.speed < 5000 ? .orange : .red))
                    .padding(.trailing, 8)
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .swipeActions(edge: .leading) {
            if source.isFailed {
                Button("刷新") {
                    
                }
                .tint(.blue)
            }
        }
    }
}
