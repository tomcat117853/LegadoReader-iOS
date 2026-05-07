import SwiftUI

struct CloudSyncView: View {
    @StateObject private var syncManager = CloudSyncManager.shared
    @State private var showingConflicts = false
    @State private var showingSyncDetail = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    SyncStatusCard(syncManager: syncManager)
                }
                
                Section("同步内容") {
                    SyncContentRow(icon: "book.fill", title: "书架书籍", description: "书籍信息和封面")
                    SyncContentRow(icon: "server.rack", title: "书源配置", description: "书源规则和设置")
                    SyncContentRow(icon: "clock.fill", title: "阅读进度", description: "阅读位置和书签")
                    SyncContentRow(icon: "slider.horizontal.3", title: "阅读设置", description: "字体、背景等偏好设置")
                }
                
                Section("操作") {
                    Button(action: {
                        Task {
                            await syncManager.fullSync()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.blue)
                            Text("立即同步")
                            Spacer()
                            if syncManager.isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(syncManager.isSyncing)
                    
                    NavigationLink(destination: SyncHistoryView()) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.orange)
                            Text("同步历史")
                            Spacer()
                            if let lastSync = syncManager.lastSyncTime {
                                Text(lastSync, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    NavigationLink(destination: SyncSettingsDetailView()) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.gray)
                            Text("同步设置")
                        }
                    }
                }
                
                Section("冲突管理") {
                    if syncManager.pendingConflicts.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("无冲突")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button(action: { showingConflicts = true }) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("\(syncManager.pendingConflicts.count) 个冲突待处理")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("高级") {
                    Button(action: {
                        Task {
                            try? await syncManager.clearCloudData()
                        }
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("清除云端数据")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("云同步")
            .sheet(isPresented: $showingConflicts) {
                ConflictResolutionView()
            }
        }
    }
}

struct SyncStatusCard: View {
    @ObservedObject var syncManager: CloudSyncManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: statusIcon)
                    .font(.system(size: 50))
                    .foregroundColor(statusColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.headline)
                    
                    Text(statusSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !syncManager.isCloudAvailable() {
                    Button("设置") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if syncManager.isSyncing {
                ProgressView(value: 0.5)
                    .progressViewStyle(.linear)
                Text("正在同步...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let error = syncManager.syncError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            HStack {
                Image(systemName: "icloud.fill")
                    .foregroundColor(syncManager.isCloudAvailable() ? .blue : .gray)
                Text(syncManager.isCloudAvailable() ? "iCloud 已连接" : "iCloud 未连接")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var statusIcon: String {
        if !syncManager.isCloudAvailable() {
            return "icloud.slash.fill"
        }
        switch syncManager.syncStatus {
        case .idle: return "icloud.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .success: return "checkmark.icloud.fill"
        case .failed: return "exclamationmark.icloud.fill"
        case .conflict: return "exclamationmark.triangle.fill"
        }
    }
    
    private var statusColor: Color {
        if !syncManager.isCloudAvailable() {
            return .gray
        }
        switch syncManager.syncStatus {
        case .idle: return .blue
        case .syncing: return .blue
        case .success: return .green
        case .failed: return .red
        case .conflict: return .orange
        }
    }
    
    private var statusTitle: String {
        if !syncManager.isCloudAvailable() {
            return "iCloud 不可用"
        }
        return syncManager.syncStatus.rawValue
    }
    
    private var statusSubtitle: String {
        if let lastSync = syncManager.lastSyncTime {
            return "上次同步: \(lastSync, style: .relative)"
        }
        return "从未同步"
    }
}

struct SyncContentRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}

struct SyncSettingsDetailView: View {
    @StateObject private var syncManager = CloudSyncManager.shared
    @State private var syncOnWiFiOnly = true
    @State private var syncOnCellular = false
    @State private var syncInterval = SyncInterval.daily
    @State private var syncBooks = true
    @State private var syncSources = true
    @State private var syncProgress = true
    @State private var syncSettings = true
    
    enum SyncInterval: String, CaseIterable {
        case manual = "手动"
        case hourly = "每小时"
        case daily = "每天"
        case weekly = "每周"
    }
    
    var body: some View {
        List {
            Section("网络设置") {
                Toggle("仅 Wi-Fi 同步", isOn: $syncOnWiFiOnly)
                Toggle("使用流量同步", isOn: $syncOnCellular)
            }
            
            Section("同步频率") {
                Picker("自动同步", selection: $syncInterval) {
                    ForEach(SyncInterval.allCases, id: \.self) { interval in
                        Text(interval.rawValue).tag(interval)
                    }
                }
            }
            
            Section("同步内容") {
                Toggle("书架书籍", isOn: $syncBooks)
                Toggle("书源配置", isOn: $syncSources)
                Toggle("阅读进度", isOn: $syncProgress)
                Toggle("阅读设置", isOn: $syncSettings)
            }
            
            Section {
                Button("立即同步") {
                    Task {
                        await syncManager.fullSync()
                    }
                }
                .disabled(syncManager.isSyncing)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("同步设置")
    }
}

struct SyncHistoryView: View {
    @StateObject private var syncManager = CloudSyncManager.shared
    @State private var syncHistory: [SyncHistoryItem] = []
    
    struct SyncHistoryItem: Identifiable {
        let id = UUID()
        let date: Date
        let type: SyncType
        let status: CloudSyncManager.SyncStatus
        let details: String
        
        enum SyncType: String {
            case upload = "上传"
            case download = "下载"
            case merge = "合并"
        }
    }
    
    var body: some View {
        List {
            if syncHistory.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("暂无同步记录")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                ForEach(syncHistory) { item in
                    HStack {
                        Image(systemName: item.type == .upload ? "arrow.up.circle.fill" : (item.type == .download ? "arrow.down.circle.fill" : "arrow.triangle.2.circlepath.circle.fill"))
                            .foregroundColor(item.type == .upload ? .blue : (item.type == .download ? .green : .purple))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.type.rawValue)
                                    .font(.headline)
                                Spacer()
                                Text(item.date, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(item.details)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Image(systemName: item.status == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(item.status == .success ? .green : .red)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("同步历史")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("刷新") {
                    loadHistory()
                }
            }
        }
        .onAppear {
            loadHistory()
        }
    }
    
    private func loadHistory() {
        syncHistory = [
            SyncHistoryItem(
                date: Date().addingTimeInterval(-3600),
                type: .upload,
                status: .success,
                details: "同步了 10 本书籍、5 个书源"
            ),
            SyncHistoryItem(
                date: Date().addingTimeInterval(-7200),
                type: .download,
                status: .success,
                details: "从云端获取了 3 本新书籍"
            ),
            SyncHistoryItem(
                date: Date().addingTimeInterval(-86400),
                type: .merge,
                status: .success,
                details: "合并了阅读进度"
            )
        ]
    }
}

struct ConflictResolutionView: View {
    @StateObject private var syncManager = CloudSyncManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if syncManager.pendingConflicts.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            Text("所有冲突已解决")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else {
                    ForEach(syncManager.pendingConflicts) { conflict in
                        ConflictItemView(conflict: conflict, syncManager: syncManager)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("冲突解决")
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

struct ConflictItemView: View {
    let conflict: CloudSyncManager.SyncConflict
    @ObservedObject var syncManager: CloudSyncManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(conflict.conflictType.rawValue)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("本地数据: \(conflict.localData.timestamp, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("云端数据: \(conflict.cloudData.timestamp, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Button("使用本地") {
                    Task {
                        await syncManager.resolveConflict(conflict, useCloud: false)
                    }
                }
                .buttonStyle(.bordered)
                
                Button("使用云端") {
                    Task {
                        await syncManager.resolveConflict(conflict, useCloud: true)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 8)
    }
}
