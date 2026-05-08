import SwiftUI

struct SidebarMenuView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var showingBookshelfEdit = false
    @State private var showingBookshelfSort = false
    @State private var showingFileImport = false
    @State private var showingStatistics = false
    @State private var showingColorManager = false
    @State private var showingSettings = false
    
    private let menuItems = [
        MenuItem(id: "profile", icon: "person.fill", title: "我的"),
        MenuItem(id: "reward", icon: "hand.thumbsup.fill", title: "激励视频"),
        MenuItem(id: "bookshelfEdit", icon: "square.and.pencil", title: "书架编辑"),
        MenuItem(id: "bookshelfSort", icon: "arrow.up.arrow.down", title: "书架排序"),
        MenuItem(id: "fileImport", icon: "arrow.down.circle", title: "文件导入"),
        MenuItem(id: "statistics", icon: "barchart", title: "书籍总统计"),
        MenuItem(id: "colorManager", icon: "palette", title: "颜色管理"),
        MenuItem(id: "settings", icon: "gear", title: "设置"),
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(menuItems) { item in
                Button(action: { handleMenuItemAction(item.id) }) {
                    HStack(spacing: 16) {
                        Image(systemName: item.icon)
                            .font(.title)
                            .foregroundColor(.primary)
                            .frame(width: 32)
                        
                        Text(item.title)
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 20)
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .background(Color(.systemBackground))
        .frame(width: UIScreen.main.bounds.width * 0.7)
        .sheet(isPresented: $showingBookshelfEdit) {
            BookshelfBatchEditView(selectedBooks: .constant([]))
        }
        .sheet(isPresented: $showingBookshelfSort) {
            // Bookshelf sort view
            Text("书架排序设置")
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
    }
    
    private func handleMenuItemAction(_ id: String) {
        switch id {
        case "bookshelfEdit": showingBookshelfEdit = true
        case "bookshelfSort": showingBookshelfSort = true
        case "fileImport": showingFileImport = true
        case "statistics": showingStatistics = true
        case "colorManager": showingColorManager = true
        case "settings": showingSettings = true
        case "profile": print("打开个人中心")
        case "reward": print("打开激励视频")
        default: break
        }
    }
}

struct MenuItem: Identifiable {
    let id: String
    let icon: String
    let title: String
}