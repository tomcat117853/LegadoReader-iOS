import SwiftUI

struct SidebarMenuView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var showingBookshelfEdit = false
    @State private var showingBookshelfSort = false
    @State private var showingFileImport = false
    @State private var showingStatistics = false
    @State private var showingColorManager = false
    @State private var showingSettings = false
    @State private var showingThemeManager = false
    @State private var showingBackupRestore = false
    @State private var showingCacheManager = false
    @State private var showingBookSource = false
    @State private var showingAudioSettings = false
    @State private var showingNotes = false
    @State private var showingDiscover = false
    @State private var showingWebBrowser = false
    
    private let menuSections = [
        MenuSection(title: "书架管理", items: [
            MenuItem(id: "bookshelfEdit", icon: "square.and.pencil", title: "书架编辑"),
            MenuItem(id: "bookshelfSort", icon: "arrow.up.arrow.down", title: "书架排序"),
            MenuItem(id: "groupManager", icon: "folder.fill", title: "分组管理"),
            MenuItem(id: "fileImport", icon: "arrow.down.circle", title: "文件导入"),
        ]),
        MenuSection(title: "数据管理", items: [
            MenuItem(id: "statistics", icon: "barchart", title: "书籍总统计"),
            MenuItem(id: "backupRestore", icon: "cloud", title: "备份&还原"),
            MenuItem(id: "cacheManager", icon: "harddrive", title: "缓存管理"),
        ]),
        MenuSection(title: "外观设置", items: [
            MenuItem(id: "themeManager", icon: "palette", title: "主题管理"),
            MenuItem(id: "colorManager", icon: "circle.fill", title: "颜色管理"),
        ]),
        MenuSection(title: "书源与搜索", items: [
            MenuItem(id: "bookSource", icon: "network", title: "书源管理"),
            MenuItem(id: "discover", icon: "compass", title: "发现"),
            MenuItem(id: "webBrowser", icon: "globe", title: "网络搜索"),
        ]),
        MenuSection(title: "功能配置", items: [
            MenuItem(id: "audioSettings", icon: "headphones", title: "听书配置"),
            MenuItem(id: "notes", icon: "note.text", title: "笔记"),
            MenuItem(id: "settings", icon: "gear", title: "设置"),
        ]),
    ]
    
    var body: some View {
        NavigationStack {
            List {
                headerSection
                
                ForEach(menuSections) { section in
                    Section(header: sectionHeader(section.title)) {
                        ForEach(section.items) { item in
                            MenuRow(item: item, action: handleMenuItemAction(item.id))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("菜单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .frame(width: UIScreen.main.bounds.width * 0.85)
        .sheet(isPresented: $showingBookshelfEdit) {
            BookshelfBatchEditView(selectedBooks: .constant([]))
                .environmentObject(BookStore.shared)
        }
        .sheet(isPresented: $showingBookshelfSort) {
            GroupSettingsView()
        }
        .sheet(isPresented: $showingFileImport) {
            FileImportView()
        }
        .sheet(isPresented: $showingStatistics) {
            ReadingProgressView()
        }
        .sheet(isPresented: $showingColorManager) {
            ThemeSkinSettingsView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingThemeManager) {
            ThemeSkinSettingsView()
        }
        .sheet(isPresented: $showingBackupRestore) {
            CloudSyncView()
        }
        .sheet(isPresented: $showingCacheManager) {
            CacheManagementView()
        }
        .sheet(isPresented: $showingBookSource) {
            BookSourceImportView()
        }
        .sheet(isPresented: $showingAudioSettings) {
            CustomAudioSourceView()
        }
        .sheet(isPresented: $showingNotes) {
            BookmarkView()
        }
        .sheet(isPresented: $showingDiscover) {
            DiscoverView()
        }
        .sheet(isPresented: $showingWebBrowser) {
            WebBrowserView()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("阅读")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 20)
        .listRowBackground(Color.clear)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.leading, 8)
    }
    
    private func handleMenuItemAction(_ id: String) {
        dismiss()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            switch id {
            case "bookshelfEdit": showingBookshelfEdit = true
            case "bookshelfSort": showingBookshelfSort = true
            case "groupManager": showingBookshelfSort = true
            case "fileImport": showingFileImport = true
            case "statistics": showingStatistics = true
            case "colorManager": showingColorManager = true
            case "settings": showingSettings = true
            case "themeManager": showingThemeManager = true
            case "backupRestore": showingBackupRestore = true
            case "cacheManager": showingCacheManager = true
            case "bookSource": showingBookSource = true
            case "audioSettings": showingAudioSettings = true
            case "notes": showingNotes = true
            case "discover": showingDiscover = true
            case "webBrowser": showingWebBrowser = true
            default: break
            }
        }
    }
}

struct MenuSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [MenuItem]
}

struct MenuItem: Identifiable {
    let id: String
    let icon: String
    let title: String
}

struct MenuRow: View {
    let item: MenuItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.title)
                    .foregroundColor(.blue)
                    .frame(width: 36)
                
                Text(item.title)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}