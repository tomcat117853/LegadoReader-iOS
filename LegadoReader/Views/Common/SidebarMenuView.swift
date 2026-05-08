import SwiftUI

struct SidebarMenuView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var showingThemeManager = false
    @State private var showingBookSourceManager = false
    @State private var showingAudioSettings = false
    @State private var showingBookSearch = false
    @State private var showingBookshelfSettings = false
    @State private var showingGroupManager = false
    @State private var showingFontSettings = false
    @State private var showingBackupRestore = false
    @State private var showingCacheManager = false
    @State private var showingPrivacySettings = false
    @State private var showingStatistics = false
    @State private var showingFileImport = false
    @State private var showingCoverCollection = false
    @State private var showingNotes = false
    @State private var showingWebBrowser = false
    @State private var showingSettings = false
    @State private var showingDiscover = false
    
    private let menuSections = [
        MenuSection(title: "书架管理", items: [
            MenuItem(id: "bookshelfLayout", icon: "square.grid.2x2", title: "书架布局管理"),
            MenuItem(id: "bookshelfSort", icon: "arrow.up.arrow.down", title: "书架排序"),
            MenuItem(id: "bookshelfSettings", icon: "books.vertical", title: "书架设置"),
            MenuItem(id: "bookshelfEdit", icon: "square.and.pencil", title: "书架编辑"),
            MenuItem(id: "groupManager", icon: "folder.fill", title: "分组管理"),
            MenuItem(id: "bookCollections", icon: "bookmark", title: "我创建的书单"),
            MenuItem(id: "importedCollections", icon: "arrow.down.to.line", title: "导入的书单"),
        ]),
        MenuSection(title: "外观设置", items: [
            MenuItem(id: "themeManager", icon: "palette", title: "主题管理"),
            MenuItem(id: "colorManager", icon: "circle.fill", title: "颜色管理"),
            MenuItem(id: "appFont", icon: "textformat", title: "App界面字体"),
            MenuItem(id: "readingFont", icon: "character.book.closed", title: "阅读字体"),
            MenuItem(id: "coverCollection", icon: "photo", title: "封面集"),
        ]),
        MenuSection(title: "书源与搜索", items: [
            MenuItem(id: "bookSource", icon: "network", title: "书源管理"),
            MenuItem(id: "bookSourceSync", icon: "repeat", title: "书源同步界面"),
            MenuItem(id: "bookSearch", icon: "magnifyingglass", title: "搜索书籍"),
            MenuItem(id: "webSearch", icon: "globe", title: "网络搜索"),
            MenuItem(id: "discover", icon: "compass", title: "发现"),
        ]),
        MenuSection(title: "功能配置", items: [
            MenuItem(id: "audioSettings", icon: "headphones", title: "听书配置"),
            MenuItem(id: "contentFilter", icon: "shield", title: "内容过滤"),
            MenuItem(id: "privacy", icon: "lock", title: "隐私功能"),
            MenuItem(id: "customization", icon: "slider.horizontal.3", title: "定制功能项"),
            MenuItem(id: "functionConfig", icon: "gearshape", title: "功能配置"),
        ]),
        MenuSection(title: "数据管理", items: [
            MenuItem(id: "backupRestore", icon: "cloud", title: "备份&还原"),
            MenuItem(id: "icloudRestore", icon: "icloud", title: "iCloud还原"),
            MenuItem(id: "cacheManager", icon: "harddrive", title: "缓存管理"),
            MenuItem(id: "exportManager", icon: "arrow.up.doc", title: "导出管理"),
            MenuItem(id: "fileImport", icon: "arrow.down.circle", title: "文件导入"),
            MenuItem(id: "clipboard", icon: "doc.on.clipboard", title: "处理剪切板"),
        ]),
        MenuSection(title: "其他", items: [
            MenuItem(id: "statistics", icon: "barchart", title: "书籍总统计"),
            MenuItem(id: "notes", icon: "note.text", title: "笔记"),
            MenuItem(id: "settings", icon: "gear", title: "设置"),
        ]),
    ]
    
    var body: some View {
        NavigationView {
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
            .navigationTitle("")
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
        .sheet(isPresented: $showingThemeManager) {
            ThemeSkinSettingsView()
        }
        .sheet(isPresented: $showingBookSourceManager) {
            BookSourceImportView()
        }
        .sheet(isPresented: $showingAudioSettings) {
            CustomAudioSourceView()
        }
        .sheet(isPresented: $showingBookshelfSettings) {
            GroupSettingsView()
        }
        .sheet(isPresented: $showingGroupManager) {
            GroupDetailView()
        }
        .sheet(isPresented: $showingFontSettings) {
            FontMappingSettingsView()
        }
        .sheet(isPresented: $showingBackupRestore) {
            CloudSyncView()
        }
        .sheet(isPresented: $showingCacheManager) {
            CacheManagementView()
        }
        .sheet(isPresented: $showingPrivacySettings) {
            // Privacy settings view
            Text("隐私功能设置")
        }
        .sheet(isPresented: $showingStatistics) {
            ReadingProgressView()
        }
        .sheet(isPresented: $showingFileImport) {
            FileImportView()
        }
        .sheet(isPresented: $showingCoverCollection) {
            CoverManagementView()
        }
        .sheet(isPresented: $showingNotes) {
            BookmarkView()
        }
        .sheet(isPresented: $showingWebBrowser) {
            WebBrowserView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingDiscover) {
            DiscoverView()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("欢迎使用LegadoReader")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("阅读无限，知识无涯")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.leading, 8)
    }
    
    private func handleMenuItemAction(_ id: String) -> () -> Void {
        return {
            switch id {
            case "themeManager": showingThemeManager = true
            case "bookSource": showingBookSourceManager = true
            case "audioSettings": showingAudioSettings = true
            case "bookSearch": showingBookSearch = true
            case "bookshelfSettings": showingBookshelfSettings = true
            case "groupManager": showingGroupManager = true
            case "appFont", "readingFont": showingFontSettings = true
            case "backupRestore": showingBackupRestore = true
            case "icloudRestore": showingBackupRestore = true
            case "cacheManager": showingCacheManager = true
            case "privacy": showingPrivacySettings = true
            case "statistics": showingStatistics = true
            case "fileImport": showingFileImport = true
            case "coverCollection": showingCoverCollection = true
            case "notes": showingNotes = true
            case "webSearch": showingWebBrowser = true
            case "settings": showingSettings = true
            case "discover": showingDiscover = true
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