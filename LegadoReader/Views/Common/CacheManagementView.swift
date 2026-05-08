import SwiftUI

struct CacheManagementView: View {
    @StateObject private var cacheManager = CacheManager.shared
    @State private var showingClearConfirmation = false
    @State private var selectedCacheType: CacheManager.CacheItem.CacheType?
    @State private var autoCleanInterval: Int = 7
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("总缓存大小")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(formatSize(cacheManager.totalCacheSize))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            cacheManager.calculateCacheSize()
                        }) {
                            if cacheManager.isCalculating {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title2)
                            }
                        }
                        .disabled(cacheManager.isCalculating)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("缓存概览")
                }
                
                Section {
                    ForEach(CacheManager.CacheItem.CacheType.allCases, id: \.id) { type in
                        CacheTypeRow(type: type, cacheManager: cacheManager) {
                            selectedCacheType = type
                            showingClearConfirmation = true
                        }
                    }
                } header: {
                    Text("缓存分类")
                }
                
                Section {
                    Button(action: {
                        showingClearConfirmation = true
                        selectedCacheType = nil
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("一键清理所有缓存")
                                .foregroundColor(.red)
                        }
                    }
                } footer: {
                    Text("清理缓存不会影响已下载的书籍内容")
                }
                
                Section {
                    Picker("自动清理周期", selection: $autoCleanInterval) {
                        Text("不自动清理").tag(0)
                        Text("3 天").tag(3)
                        Text("7 天").tag(7)
                        Text("14 天").tag(14)
                        Text("30 天").tag(30)
                    }
                    
                    Button("保存设置") {
                        UserDefaults.standard.set(autoCleanInterval, forKey: "AutoCleanInterval")
                        if autoCleanInterval > 0 {
                            cacheManager.clearOldCache(olderThan: autoCleanInterval)
                        }
                    }
                    .foregroundColor(.blue)
                } header: {
                    Text("自动清理设置")
                } footer: {
                    Text("自动清理超过指定天数的缓存文件")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("缓存说明")
                            .font(.headline)
                        
                        Group {
                            Text("书籍缓存：已下载的书籍章节内容")
                            Text("章节缓存：单个章节的离线内容")
                            Text("封面缓存：书籍封面图片")
                            Text("图片缓存：阅读中加载的图片")
                            Text("音频缓存：听书功能缓存")
                            Text("临时文件：应用运行时的临时数据")
                            Text("数据库：应用的本地数据库文件")
                        }
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("帮助")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("缓存管理")
            .navigationBarTitleDisplayMode(.inline)
            .alert("确认清理", isPresented: $showingClearConfirmation) {
                Button("取消", role: .cancel) {
                }
                Button("清理", role: .destructive) {
                    if let type = selectedCacheType {
                        cacheManager.clearCache(type: type)
                    } else {
                        cacheManager.clearAllCache()
                    }
                }
            } message: {
                if let type = selectedCacheType {
                    let size = cacheManager.getCacheSize(for: type)
                    Text("确定要清理 \(type.displayName) (\(formatSize(size))) 吗？")
                } else {
                    Text("确定要清理所有缓存吗？")
                }
            }
            .onAppear {
                autoCleanInterval = UserDefaults.standard.integer(forKey: "AutoCleanInterval")
                if autoCleanInterval == 0 {
                    autoCleanInterval = 7
                }
            }
        }
    }
    
    private func formatSize(_ size: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct CacheTypeRow: View {
    let type: CacheManager.CacheItem.CacheType
    @ObservedObject var cacheManager: CacheManager
    let onClear: () -> Void
    
    var cacheSize: Int64 {
        cacheManager.getCacheSize(for: type)
    }
    
    var body: some View {
        HStack {
            Image(systemName: type.iconName)
                .foregroundColor(getTypeColor(type))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(type.displayName)
                    .font(.body)
                
                Text("\(cacheManager.getCacheItems(for: type).count) 个文件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatSize(cacheSize))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: onClear) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .disabled(cacheSize == 0)
        }
        .padding(.vertical, 4)
    }
    
    private func formatSize(_ size: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    private func getTypeColor(_ type: CacheManager.CacheItem.CacheType) -> Color {
        switch type {
        case .book: return .blue
        case .chapter: return .green
        case .cover: return .purple
        case .image: return .orange
        case .audio: return .red
        case .temp: return .gray
        case .database: return .cyan
        case .other: return .secondary
        }
    }
}

struct CacheManagementView_Previews: PreviewProvider {
    static var previews: some View {
        CacheManagementView()
    }
}
