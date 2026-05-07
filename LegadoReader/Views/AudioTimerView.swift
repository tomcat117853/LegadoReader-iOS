import SwiftUI

struct MultiLevelChapterListView: View {
    @StateObject private var chapterManager = MultiLevelChapterManager.shared
    @State private var chapters: [MultiLevelChapter] = []
    @State private var searchText = ""
    @State private var showingSettings = false
    
    let bookId: String
    let chaptersData: [Chapter]
    let currentChapterId: String?
    let onChapterSelect: (Chapter) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                
                chapterList
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { chapterManager.expandAll() }) {
                            Label("展开全部", systemImage: "arrow.down.right.and.arrow.up.left")
                        }
                        
                        Button(action: { chapterManager.collapseAll() }) {
                            Label("折叠全部", systemImage: "arrow.up.left.and.arrow.down.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                ChapterListSettingsView()
            }
            .onAppear {
                loadChapters()
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
    
    private var chapterList: some View {
        List {
            ForEach(filteredChapters) { chapter in
                ChapterRowView(
                    chapter: chapter,
                    isSelected: chapter.originalIndex == currentChapterId,
                    onTap: {
                        if let chapterData = chaptersData[safe: chapter.originalIndex] {
                            onChapterSelect(chapterData)
                        }
                    },
                    onToggleExpand: {
                        chapterManager.toggleExpand(chapter.id)
                        loadChapters()
                    }
                )
            }
        }
        .listStyle(.plain)
    }
    
    private var filteredChapters: [MultiLevelChapter] {
        if searchText.isEmpty {
            return chapters
        } else {
            return chapters.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private func loadChapters() {
        chapters = chapterManager.parseChapters(from: chaptersData)
    }
}

struct ChapterRowView: View {
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
                    Spacer().frame(width: 16)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(chapter.title)
                        .font(chapter.level == 0 ? .body : .subheadline)
                        .fontWeight(chapter.level == 0 ? .medium : .regular)
                        .foregroundColor(isSelected ? .blue : .primary)
                        .lineLimit(2)
                        .padding(.leading, CGFloat(chapter.level) * 12)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "play.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ChapterListSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var chapterManager = MultiLevelChapterManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Button(action: {
                        chapterManager.expandAll()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .foregroundColor(.blue)
                            Text("展开全部章节")
                        }
                    }
                    
                    Button(action: {
                        chapterManager.collapseAll()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .foregroundColor(.blue)
                            Text("折叠全部章节")
                        }
                    }
                } header: {
                    Text("显示设置")
                }
                
                Section {
                    Text("多级目录会自动识别书籍章节结构")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("说明")
                }
            }
            .navigationTitle("目录设置")
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

struct AudioTimerView: View {
    @StateObject private var timerManager = AudioTimerManager.shared
    @Environment(\.dismiss) var dismiss
    
    let onTimerComplete: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                timerDisplay
                
                timerControls
                
                durationPicker
                
                Spacer()
            }
            .padding()
            .navigationTitle("定时设置")
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
    
    private var timerDisplay: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: timerManager.isTimerRunning ? CGFloat(timerManager.remainingTime / timerManager.timerDuration) : 0)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timerManager.remainingTime)
                
                VStack(spacing: 4) {
                    Text(timerManager.formattedRemainingTime)
                        .font(.system(size: 48, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    if timerManager.isTimerRunning {
                        Text("剩余时间")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("设置定时")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var timerControls: some View {
        HStack(spacing: 20) {
            if timerManager.isTimerRunning {
                Button(action: { timerManager.pauseTimer() }) {
                    Image(systemName: "pause.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.orange)
                        .clipShape(Circle())
                }
                
                Button(action: { 
                    timerManager.stopTimer()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            } else {
                Button(action: { timerManager.startTimer() }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("开始")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(30)
                }
            }
        }
    }
    
    private var durationPicker: some View {
        VStack(spacing: 16) {
            Text("定时时长")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(durationOptions, id: \.0) { option in
                        Button(action: {
                            timerManager.setDuration(option.0)
                        }) {
                            Text(option.1)
                                .font(.subheadline)
                                .foregroundColor(timerManager.timerDuration == option.0 ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(timerManager.timerDuration == option.0 ? Color.blue : Color.gray.opacity(0.2))
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var durationOptions: [(TimeInterval, String)] {
        [
            (600, "10分钟"),
            (900, "15分钟"),
            (1800, "30分钟"),
            (2700, "45分钟"),
            (3600, "1小时"),
            (5400, "1.5小时"),
            (7200, "2小时"),
            (10800, "3小时")
        ]
    }
}

struct AudioSyncSettingsView: View {
    @StateObject private var syncManager = AudioSyncManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("启用听书同步", isOn: $syncManager.syncEnabled)
                        .tint(.blue)
                    
                    if syncManager.syncEnabled {
                        Stepper("同步间隔: \(Int(syncManager.syncInterval / 60))分钟", 
                               value: Binding(
                                get: { syncManager.syncInterval / 60 },
                                set: { syncManager.setSyncInterval($0 * 60) }
                               ),
                               in: 1...60,
                               step: 1)
                        
                        Toggle("仅在WiFi下同步", isOn: $syncManager.autoSyncOnWifi)
                            .tint(.green)
                    }
                } header: {
                    Text("同步设置")
                }
                
                Section {
                    if let lastSync = syncManager.lastSyncTime {
                        HStack {
                            Text("上次同步")
                            Spacer()
                            Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("待同步任务")
                        Spacer()
                        Text("\(syncManager.pendingSyncCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    if let error = syncManager.syncError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Button(action: {
                        Task {
                            await syncManager.syncNow()
                        }
                    }) {
                        HStack {
                            if syncManager.isSyncing {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(syncManager.isSyncing ? "同步中..." : "立即同步")
                        }
                    }
                    .disabled(syncManager.isSyncing || !syncManager.syncEnabled)
                } header: {
                    Text("同步状态")
                }
                
                Section {
                    Button(role: .destructive, action: {
                        syncManager.clearAllSyncHistory()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("清除同步历史")
                        }
                    }
                } header: {
                    Text("数据管理")
                }
            }
            .navigationTitle("听书同步")
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

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
