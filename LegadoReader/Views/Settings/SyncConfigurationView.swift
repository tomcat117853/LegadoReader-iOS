import SwiftUI

struct SyncConfigurationView: View {
    @StateObject private var configManager = SyncConfigurationManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("配置类型", selection: $selectedTab) {
                Text("基础配置").tag(0)
                Text("分组同步").tag(1)
                Text("书籍同步").tag(2)
                Text("文件同步").tag(3)
            }
            .pickerStyle(.segmented)
            .padding()
            
            TabView(selection: $selectedTab) {
                BasicSyncConfigView()
                    .tag(0)
                
                GroupSyncConfigListView()
                    .tag(1)
                
                BookSyncConfigListView()
                    .tag(2)
                
                FileSyncConfigView()
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("同步配置")
    }
}

struct BasicSyncConfigView: View {
    @StateObject private var configManager = SyncConfigurationManager.shared
    
    var body: some View {
        List {
            Section("自动同步") {
                Toggle("启用自动同步", isOn: $configManager.syncConfiguration.enableAutoSync)
                    .tint(.blue)
                
                Toggle("仅 Wi-Fi 同步", isOn: $configManager.syncConfiguration.syncOnWiFiOnly)
                    .tint(.blue)
                
                Toggle("使用流量同步", isOn: $configManager.syncConfiguration.syncOnCellular)
                    .tint(.blue)
            }
            
            Section("同步频率") {
                Picker("同步间隔", selection: $configManager.syncConfiguration.syncInterval) {
                    ForEach(SyncConfigurationManager.SyncConfiguration.SyncInterval.allCases, id: \.self) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Section("同步方向") {
                ForEach(SyncConfigurationManager.SyncConfiguration.DefaultSyncDirection.allCases, id: \.self) { direction in
                    Button(action: {
                        configManager.syncConfiguration.syncDirection = direction
                        configManager.saveConfiguration()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(direction.displayName)
                                    .foregroundColor(.primary)
                                Text(directionDescription(direction))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if configManager.syncConfiguration.syncDirection == direction {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            Section("冲突处理") {
                Picker("冲突解决策略", selection: $configManager.syncConfiguration.conflictResolution) {
                    ForEach(SyncConfigurationManager.SyncConfiguration.ConflictResolution.allCases, id: \.self) { resolution in
                        Text(resolution.displayName).tag(resolution)
                    }
                }
            }
            
            Section("其他选项") {
                Toggle("同步已删除项目", isOn: $configManager.syncConfiguration.syncDeletedItems)
                    .tint(.blue)
                
                Toggle("同步元数据", isOn: $configManager.syncConfiguration.syncMetadata)
                    .tint(.blue)
                
                HStack {
                    Text("最大同步大小")
                    Spacer()
                    Text(formatSize(configManager.syncConfiguration.maxSyncSize))
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                NavigationLink(destination: SyncStatisticsView()) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.blue)
                        Text("同步统计")
                    }
                }
                
                Button(action: {
                    configManager.resetToDefaults()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.orange)
                        Text("恢复默认设置")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .onChange(of: configManager.syncConfiguration.enableAutoSync) { _ in
            configManager.saveConfiguration()
        }
    }
    
    private func directionDescription(_ direction: SyncConfigurationManager.SyncConfiguration.DefaultSyncDirection) -> String {
        switch direction {
        case .bidirectional: return "本地和云端数据双向同步"
        case .uploadOnly: return "只上传本地数据到云端"
        case .downloadOnly: return "只从云端下载数据到本地"
        }
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct GroupSyncConfigListView: View {
    @StateObject private var configManager = SyncConfigurationManager.shared
    @StateObject private var bookGroupManager = BookGroupManager.shared
    @State private var showingAddGroup = false
    @State private var selectedGroup: String?
    
    var body: some View {
        List {
            Section {
                Button(action: { showingAddGroup = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("添加分组同步配置")
                    }
                }
            }
            
            if configManager.groupSyncSettings.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("暂无分组同步配置")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("为特定分组设置同步规则")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                ForEach(Array(configManager.groupSyncSettings.values)) { config in
                    NavigationLink(destination: GroupSyncConfigDetailView(config: config)) {
                        GroupSyncConfigRow(config: config)
                    }
                }
                .onDelete { indexSet in
                    let configs = Array(configManager.groupSyncSettings.values)
                    for index in indexSet {
                        configManager.removeGroupSyncConfig(configs[index].groupId)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("分组同步")
        .sheet(isPresented: $showingAddGroup) {
            AddGroupSyncConfigSheet()
        }
    }
}

struct GroupSyncConfigRow: View {
    let config: SyncConfigurationManager.GroupSyncConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                Text(config.groupName)
                    .font(.headline)
                Spacer()
                if config.syncEnabled {
                    Text("已启用")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(4)
                } else {
                    Text("已禁用")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            HStack(spacing: 12) {
                if config.syncBooks {
                    Label("书籍", systemImage: "book.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if config.syncProgress {
                    Label("进度", systemImage: "clock.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if config.syncNotes {
                    Label("笔记", systemImage: "note.text")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if config.syncBookmarks {
                    Label("书签", systemImage: "bookmark.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct GroupSyncConfigDetailView: View {
    @State var config: SyncConfigurationManager.GroupSyncConfig
    @StateObject private var configManager = SyncConfigurationManager.shared
    
    var body: some View {
        List {
            Section {
                Toggle("启用同步", isOn: $config.syncEnabled)
                    .tint(.blue)
            }
            
            Section("同步方向") {
                Picker("同步方向", selection: $config.syncDirection) {
                    ForEach(SyncConfigurationManager.SyncConfiguration.DefaultSyncDirection.allCases, id: \.self) { direction in
                        Text(direction.displayName).tag(direction)
                    }
                }
            }
            
            Section("同步内容") {
                Toggle("同步书籍", isOn: $config.syncBooks)
                    .tint(.blue)
                Toggle("同步进度", isOn: $config.syncProgress)
                    .tint(.blue)
                Toggle("同步笔记", isOn: $config.syncNotes)
                    .tint(.blue)
                Toggle("同步书签", isOn: $config.syncBookmarks)
                    .tint(.blue)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(config.groupName)
        .onDisappear {
            configManager.updateGroupSyncConfig(config)
        }
    }
}

struct AddGroupSyncConfigSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var configManager = SyncConfigurationManager.shared
    @StateObject private var bookGroupManager = BookGroupManager.shared
    @State private var selectedGroupId: String?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(bookGroupManager.groups) { group in
                    Button(action: {
                        configManager.addGroupSyncConfig(group.id, groupName: group.name)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            Text(group.name)
                            Spacer()
                            if configManager.groupSyncSettings[group.id] != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("选择分组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct BookSyncConfigListView: View {
    @StateObject private var configManager = SyncConfigurationManager.shared
    @State private var showingAddBook = false
    @State private var searchText = ""
    
    var filteredBooks: [SyncConfigurationManager.BookSyncConfig] {
        if searchText.isEmpty {
            return Array(configManager.bookSyncSettings.values)
        }
        return Array(configManager.bookSyncSettings.values.filter {
            $0.bookTitle.localizedCaseInsensitiveContains(searchText)
        })
    }
    
    var body: some View {
        List {
            Section {
                Button(action: { showingAddBook = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("添加书籍同步配置")
                    }
                }
            }
            
            if configManager.bookSyncSettings.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("暂无书籍同步配置")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("为特定书籍设置同步规则")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                ForEach(filteredBooks) { config in
                    NavigationLink(destination: BookSyncConfigDetailView(config: config)) {
                        BookSyncConfigRow(config: config)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        configManager.removeBookSyncConfig(filteredBooks[index].bookId)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("书籍同步")
        .searchable(text: $searchText, prompt: "搜索书籍")
        .sheet(isPresented: $showingAddBook) {
            AddBookSyncConfigSheet()
        }
    }
}

struct BookSyncConfigRow: View {
    let config: SyncConfigurationManager.BookSyncConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(config.bookTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if config.syncEnabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            HStack(spacing: 8) {
                Text(config.syncDirection.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                
                if config.syncOriginalFile {
                    Label("原文件", systemImage: "doc.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct BookSyncConfigDetailView: View {
    @State var config: SyncConfigurationManager.BookSyncConfig
    @StateObject private var configManager = SyncConfigurationManager.shared
    
    var body: some View {
        List {
            Section {
                Toggle("启用同步", isOn: $config.syncEnabled)
                    .tint(.blue)
            }
            
            Section("同步方向") {
                Picker("同步方向", selection: $config.syncDirection) {
                    ForEach(SyncConfigurationManager.SyncConfiguration.DefaultSyncDirection.allCases, id: \.self) { direction in
                        Text(direction.displayName).tag(direction)
                    }
                }
            }
            
            Section("同步内容") {
                Toggle("阅读进度", isOn: $config.syncProgress)
                    .tint(.blue)
                Toggle("笔记", isOn: $config.syncNotes)
                    .tint(.blue)
                Toggle("书签", isOn: $config.syncBookmarks)
                    .tint(.blue)
                Toggle("原文件", isOn: $config.syncOriginalFile)
                    .tint(.blue)
                Toggle("封面", isOn: $config.syncCover)
                    .tint(.blue)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(config.bookTitle)
        .onDisappear {
            configManager.updateBookSyncConfig(config)
        }
    }
}

struct AddBookSyncConfigSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var configManager = SyncConfigurationManager.shared
    @StateObject private var bookStore = BookStore.shared
    @State private var searchText = ""
    
    var filteredBooks: [Book] {
        if searchText.isEmpty {
            return bookStore.books
        }
        return bookStore.books.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredBooks) { book in
                    Button(action: {
                        configManager.addBookSyncConfig(book.id, bookTitle: book.name)
                        dismiss()
                    }) {
                        HStack {
                            Text(book.name)
                                .lineLimit(1)
                            Spacer()
                            if configManager.bookSyncSettings[book.id] != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("选择书籍")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索书籍")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FileSyncConfigView: View {
    @StateObject private var configManager = SyncConfigurationManager.shared
    
    var body: some View {
        List {
            Section("同步内容") {
                Toggle("原文件", isOn: $configManager.fileSyncSettings.syncOriginalFiles)
                    .tint(.blue)
                Toggle("封面", isOn: $configManager.fileSyncSettings.syncCovers)
                    .tint(.blue)
                Toggle("标注", isOn: $configManager.fileSyncSettings.syncAnnotations)
                    .tint(.blue)
                Toggle("笔记", isOn: $configManager.fileSyncSettings.syncNotes)
                    .tint(.blue)
                Toggle("书签", isOn: $configManager.fileSyncSettings.syncBookmarks)
                    .tint(.blue)
                Toggle("阅读进度", isOn: $configManager.fileSyncSettings.syncReadingProgress)
                    .tint(.blue)
            }
            
            Section("数据源") {
                Toggle("书源", isOn: $configManager.fileSyncSettings.syncBookSources)
                    .tint(.blue)
                Toggle("OPDS订阅", isOn: $configManager.fileSyncSettings.syncOPDSFeeds)
                    .tint(.blue)
                Toggle("阅读历史", isOn: $configManager.fileSyncSettings.syncReadHistory)
                    .tint(.blue)
                Toggle("自定义书源", isOn: $configManager.fileSyncSettings.syncCustomSources)
                    .tint(.blue)
            }
            
            Section("文件格式") {
                Picker("同步格式", selection: $configManager.fileSyncSettings.fileFormat) {
                    ForEach(SyncConfigurationManager.FileSyncConfig.FileSyncFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
            }
            
            Section("大小限制") {
                HStack {
                    Text("封面大小限制")
                    Spacer()
                    Text(formatSize(configManager.fileSyncSettings.maxCoverSize))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("书籍文件大小限制")
                    Spacer()
                    Text(formatSize(configManager.fileSyncSettings.maxBookFileSize))
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("文件同步")
        .onChange(of: configManager.fileSyncSettings.syncOriginalFiles) { _ in
            configManager.saveConfiguration()
        }
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct SyncStatisticsView: View {
    @StateObject private var configManager = SyncConfigurationManager.shared
    @State private var statistics: SyncConfigurationManager.SyncStatistics?
    
    var body: some View {
        List {
            Section("概览") {
                StatRow(title: "分组配置数", value: "\(statistics?.totalGroups ?? 0)", icon: "folder.fill", color: .blue)
                StatRow(title: "书籍配置数", value: "\(statistics?.totalBooks ?? 0)", icon: "book.fill", color: .green)
                StatRow(title: "启用分组", value: "\(statistics?.enabledGroups ?? 0)", icon: "checkmark.circle.fill", color: .green)
                StatRow(title: "启用书籍", value: "\(statistics?.enabledBooks ?? 0)", icon: "checkmark.circle.fill", color: .green)
            }
            
            Section("同步方向分布") {
                if let directions = statistics?.syncDirections {
                    ForEach(Array(directions.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key)
                            Spacer()
                            Text("\(directions[key] ?? 0) 本")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section("文件设置") {
                if let settings = statistics?.fileSettings {
                    ForEach(Array(settings.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key)
                            Spacer()
                            Image(systemName: (settings[key] ?? false) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor((settings[key] ?? false) ? .green : .gray)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("同步统计")
        .onAppear {
            statistics = configManager.getSyncStatistics()
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }
}
