import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var readerSettings: ReaderSettings
    @State private var showingAbout = false
    @State private var showingClearCache = false
    @StateObject private var syncManager = CloudSyncManager.shared
    
    var body: some View {
        NavigationView {
            List {
                // 阅读设置
                Section("阅读设置") {
                    NavigationLink(destination: ReaderSettingsView(settings: readerSettings)) {
                        Label("阅读界面设置", systemImage: "textformat.size")
                    }
                    
                    NavigationLink(destination: ThemeSkinSettingsView()) {
                        HStack {
                            Image(systemName: "palette")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("主题设置")
                                Text("切换全局主题外观")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    NavigationLink(destination: TitleSegmentationSettingsView()) {
                        HStack {
                            Image(systemName: "text.badge.checkmark")
                                .foregroundColor(.blue)
                            Text("标题分段设置")
                        }
                    }
                    
                    NavigationLink(destination: AnnotationStyleSettingsView()) {
                        HStack {
                            Image(systemName: "highlighter")
                                .foregroundColor(.orange)
                            Text("标记外观设置")
                        }
                    }
                    
                    NavigationLink(destination: FontMappingSettingsView()) {
                        HStack {
                            Image(systemName: "textformat")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("字体映射")
                                Text("自定义字符范围的显示字体")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    NavigationLink(destination: ComicReadingSettingsView()) {
                        HStack {
                            Image(systemName: "books.vertical.fill")
                                .foregroundColor(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("漫画模式设置")
                                Text("图片模式、翻页方式、缩放放大镜")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Toggle("夜间模式跟随系统", isOn: .constant(false))
                    
                    Toggle("自动翻页", isOn: $readerSettings.isAutoReading)
                    
                    if readerSettings.isAutoReading {
                        HStack {
                            Text("翻页速度")
                            Spacer()
                            Text("\(String(format: "%.1f", readerSettings.autoReadSpeed)) 秒")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 云同步
                Section("云同步") {
                    NavigationLink(destination: CloudSyncView()) {
                        HStack {
                            Image(systemName: "icloud.fill")
                                .foregroundColor(.blue)
                            Text("iCloud 同步")
                            Spacer()
                            if syncManager.isSyncing {
                                ProgressView()
                            } else if syncManager.syncStatus == .success {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    NavigationLink(destination: SyncConfigurationView()) {
                        HStack {
                            Image(systemName: "gear.badge")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("同步配置")
                                Text("分组、书籍、文件同步方式")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if let lastSync = syncManager.lastSyncTime {
                        HStack {
                            Text("上次同步")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 书架设置
                Section("书架设置") {
                    Toggle("自动更新书籍", isOn: .constant(true))
                    
                    Toggle("更新提醒", isOn: .constant(true))
                    
                    HStack {
                        Text("书架排序方式")
                        Spacer()
                        Text("最近阅读")
                            .foregroundColor(.secondary)
                    }
                }
                
                // 缓存管理
                Section("缓存管理") {
                    HStack {
                        Text("缓存大小")
                        Spacer()
                        Text(DownloadManager.shared.getCacheSize())
                            .foregroundColor(.secondary)
                    }
                    
                    Button("清除缓存") {
                        showingClearCache = true
                    }
                    .foregroundColor(.red)
                }
                
                // 数据管理
                Section("数据管理") {
                    Button("备份数据") {
                        if let path = BackupManager.shared.createBackup() {
                            print("Backup created: \(path)")
                        }
                    }
                    
                    Button("恢复数据") {
                        // 恢复数据
                    }
                    
                    Button("导出书架") {
                        // 导出书架
                    }
                }
                
                // 高级功能
                Section("高级功能") {
                    NavigationLink(destination: WebServiceSettingsView()) {
                        HStack {
                            Image(systemName: "server.rack")
                                .foregroundColor(.blue)
                            Text("Web 服务")
                            Spacer()
                            if WebServiceManager.shared.isRunning {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                    
                    NavigationLink(destination: WebDAVSettingsView()) {
                        HStack {
                            Image(systemName: "externaldrive.connected.to.line.below")
                                .foregroundColor(.purple)
                            Text("WebDAV 同步")
                        }
                    }
                    
                    NavigationLink(destination: ChineseConverterSettingsView()) {
                        HStack {
                            Image(systemName: "character.bubble")
                                .foregroundColor(.orange)
                            Text("简繁转换")
                        }
                    }
                    
                    NavigationLink(destination: PageTurnSettingsView()) {
                        HStack {
                            Image(systemName: "book.pages")
                                .foregroundColor(.green)
                            Text("翻页设置")
                        }
                    }
                    
                    NavigationLink(destination: TXTImportSettingsView()) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
                            Text("TXT导入设置")
                        }
                    }
                }
                
                // 关于
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink(destination: AboutView()) {
                        Label("关于 LegadoReader", systemImage: "info.circle")
                    }
                    
                    Link(destination: URL(string: "https://github.com/gedoor/legado")!) {
                        Label("Legado 开源项目", systemImage: "link")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("设置")
            .alert("清除缓存", isPresented: $showingClearCache) {
                Button("取消", role: .cancel) {}
                Button("确定", role: .destructive) {
                    Task {
                        try? await DownloadManager.shared.clearAllCache()
                    }
                }
            } message: {
                Text("确定要清除所有缓存吗？")
            }
        }
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("LegadoReader")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("iOS 版本")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    Text("一款基于 Legado 书源规则的 iOS 阅读器")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
            
            Section("功能特性") {
                FeatureRow(icon: "magnifyingglass", title: "书源搜索", description: "支持多书源并发搜索")
                FeatureRow(icon: "book.open", title: "阅读器", description: "自定义字体、背景、翻页模式")
                FeatureRow(icon: "newspaper", title: "RSS订阅", description: "订阅你喜欢的内容源")
                FeatureRow(icon: "arrow.down.circle", title: "书源导入", description: "支持 Legado 书源格式")
            }
            
            Section("开源协议") {
                Text("本项目基于 Legado 开源项目开发，遵循开源协议。")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
