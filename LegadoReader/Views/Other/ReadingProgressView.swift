import SwiftUI

struct ReadingProgressView: View {
    @StateObject private var progressSync = ReadingProgressSync.shared
    @State private var showingSyncSettings = false
    @State private var showingStats = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    SyncStatusView(progressSync: progressSync)
                } header: {
                    Text("同步状态")
                }
                
                Section {
                    NavigationLink(destination: RecentReadView()) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                            Text("最近阅读")
                            Spacer()
                            Text("\(progressSync.getAllBooksProgress().count) 本")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink(destination: AllBooksProgressView()) {
                        HStack {
                            Image(systemName: "books.vertical")
                                .foregroundColor(.green)
                            Text("全部阅读进度")
                        }
                    }
                    
                    Button(action: { showingStats = true }) {
                        HStack {
                            Image(systemName: "chart.bar")
                                .foregroundColor(.orange)
                            Text("阅读统计")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("阅读进度")
                }
                
                Section {
                    Button(action: {
                        progressSync.syncFromiCloud()
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.blue)
                            Text("从 iCloud 恢复")
                            Spacer()
                            if progressSync.isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(progressSync.isSyncing)
                    
                    if let lastSync = progressSync.lastSyncTime {
                        HStack {
                            Text("上次同步")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("iCloud 同步")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("阅读进度")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSyncSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSyncSettings) {
                SyncSettingsView()
            }
            .sheet(isPresented: $showingStats) {
                ReadingStatsView()
            }
        }
    }
}

struct SyncStatusView: View {
    @ObservedObject var progressSync: ReadingProgressSync
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: progressSync.syncError == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(progressSync.syncError == nil ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(progressSync.syncError == nil ? "同步正常" : "同步异常")
                        .font(.headline)
                    
                    if let error = progressSync.syncError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastSync = progressSync.lastSyncTime {
                        Text("上次同步: \(lastSync, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            if progressSync.isSyncing {
                HStack {
                    ProgressView()
                        .progressViewStyle(.linear)
                    Text("同步中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct RecentReadView: View {
    @StateObject private var progressSync = ReadingProgressSync.shared
    
    var body: some View {
        List {
            ForEach(progressSync.getRecentlyReadBooks()) { progress in
                RecentReadItem(progress: progress)
            }
        }
        .listStyle(.plain)
        .navigationTitle("最近阅读")
        .overlay {
            if progressSync.getRecentlyReadBooks().isEmpty {
                EmptyStateView(
                    icon: "clock",
                    title: "暂无阅读记录",
                    message: "开始阅读后这里会显示您的阅读历史"
                )
            }
        }
    }
}

struct RecentReadItem: View {
    let progress: ReadingProgressSync.ReadingProgress
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 70)
                .overlay(
                    Image(systemName: "book.fill")
                        .foregroundColor(.gray)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(progress.bookName)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                
                Text(progress.chapterTitle)
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                    .lineLimit(1)
                
                HStack {
                    Text("\(progress.chapterIndex + 1)/\(progress.totalChapters)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: Double(progress.chapterIndex + 1), total: Double(progress.totalChapters))
                        .progressViewStyle(.linear)
                        .frame(width: 60)
                }
            }
            
            Spacer()
            
            Text(progress.lastReadTime, style: .relative)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct AllBooksProgressView: View {
    @StateObject private var progressSync = ReadingProgressSync.shared
    @State private var searchText = ""
    
    var filteredProgress: [ReadingProgressSync.ReadingProgress] {
        if searchText.isEmpty {
            return progressSync.getAllBooksProgress()
        }
        return progressSync.getAllBooksProgress().filter {
            $0.bookName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredProgress) { progress in
                BookProgressItem(progress: progress)
            }
            .onDelete(perform: deleteProgress)
        }
        .listStyle(.plain)
        .navigationTitle("全部进度")
        .searchable(text: $searchText, prompt: "搜索书籍")
        .overlay {
            if progressSync.getAllBooksProgress().isEmpty {
                EmptyStateView(
                    icon: "books.vertical",
                    title: "暂无阅读进度",
                    message: "您的阅读进度会显示在这里"
                )
            }
        }
    }
    
    private func deleteProgress(at offsets: IndexSet) {
        for index in offsets {
            let progress = filteredProgress[index]
            progressSync.removeProgress(for: progress.bookId)
        }
    }
}

struct BookProgressItem: View {
    let progress: ReadingProgressSync.ReadingProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(progress.bookName)
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Text("\(Int(progress.readPercentage * 100))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: progress.readPercentage)
                .progressViewStyle(.linear)
            
            HStack {
                Text("读至: \(progress.chapterTitle)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Text("第 \(progress.chapterIndex + 1)/\(progress.totalChapters) 章")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Text("已读章节: \(progress.readChapters.count)/\(progress.totalChapters)")
                .font(.system(size: 12))
                .foregroundColor(.green)
        }
        .padding(.vertical, 8)
    }
}

struct ReadingStatsView: View {
    @StateObject private var progressSync = ReadingProgressSync.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    let stats = progressSync.getReadingStats()
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(title: "阅读书籍", value: "\(stats.totalBooks)", icon: "book.fill", color: .blue)
                        StatCard(title: "已读章节", value: "\(stats.totalReadChapters)", icon: "doc.text.fill", color: .green)
                        StatCard(title: "本周阅读", value: "\(stats.weeklyReadBooks)", icon: "calendar", color: .orange)
                        StatCard(title: "本月阅读", value: "\(stats.monthlyReadBooks)", icon: "calendar.badge.clock", color: .purple)
                    }
                    
                    if let lastRead = stats.lastReadTime {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("最近阅读")
                                .font(.headline)
                            
                            Text(lastRead, style: .relative)
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("阅读统计")
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

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SyncSettingsView: View {
    @State private var autoSyncEnabled = true
    @State private var syncOnCellular = false
    @State private var syncInterval = SyncInterval.manual
    @Environment(\.dismiss) var dismiss
    
    enum SyncInterval: String, CaseIterable {
        case manual = "手动"
        case hourly = "每小时"
        case daily = "每天"
        case weekly = "每周"
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Toggle("自动同步", isOn: $autoSyncEnabled)
                    Toggle("使用流量同步", isOn: $syncOnCellular)
                } header: {
                    Text("同步设置")
                }
                
                Section {
                    Picker("同步频率", selection: $syncInterval) {
                        ForEach(SyncInterval.allCases, id: \.self) { interval in
                            Text(interval.rawValue).tag(interval)
                        }
                    }
                } header: {
                    Text("同步间隔")
                }
                
                Section {
                    Button("立即同步") {
                        ReadingProgressSync.shared.syncFromiCloud()
                    }
                    
                    Button("清除同步数据") {
                        // 清除 iCloud 数据
                    }
                    .foregroundColor(.red)
                } header: {
                    Text("手动操作")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("同步设置")
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

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.title3)
                .foregroundColor(.gray)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
