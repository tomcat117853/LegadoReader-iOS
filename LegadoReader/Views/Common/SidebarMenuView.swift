import SwiftUI

struct SidebarMenuView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var showingBookshelfEdit = false
    @State private var showingBookshelfSort = false
    @State private var showingFileImport = false
    @State private var showingStatistics = false
    @State private var showingColorManager = false
    @State private var showingSettings = false
    @State private var showingBookSource = false
    @State private var showingBookSea = false
    @State private var showingContentFilter = false
    
    private let menuItems = [
        SidebarMenuItem(id: "my", icon: "person", title: "我的"),
        SidebarMenuItem(id: "incentive", icon: "hand.thumbsup", title: "激励视频"),
        SidebarMenuItem(id: "bookshelfEdit", icon: "square.and.pencil", title: "书架编辑"),
        SidebarMenuItem(id: "bookshelfSort", icon: "arrow.up.arrow.down", title: "书架排序"),
        SidebarMenuItem(id: "fileImport", icon: "arrow.down.circle", title: "文件导入"),
        SidebarMenuItem(id: "statistics", icon: "barchart", title: "书籍总统计"),
        SidebarMenuItem(id: "colorManager", icon: "palette", title: "颜色管理"),
        SidebarMenuItem(id: "bookSource", icon: "network", title: "书源管理"),
        SidebarMenuItem(id: "bookSea", icon: "book.horizontal", title: "书海无涯"),
        SidebarMenuItem(id: "contentFilter", icon: "filter", title: "内容过滤"),
        SidebarMenuItem(id: "settings", icon: "gear", title: "设置"),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(menuItems) { item in
                Button(action: { handleMenuItemAction(item.id) }) {
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.title)
                            .foregroundColor(.primary)
                        
                        Text(item.title)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .background(Color(.systemBackground))
        .cornerRadius(16, corners: [.topLeft, .bottomLeft])
        .shadow(radius: 8)
        .frame(width: 260)
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
        .sheet(isPresented: $showingBookSource) {
            BookSourceImportView()
        }
        .sheet(isPresented: $showingBookSea) {
            BookSeaView()
        }
        .sheet(isPresented: $showingContentFilter) {
            ContentFilterSettingsView()
        }
    }
    
    private func handleMenuItemAction(_ id: String) {
        dismiss()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            switch id {
            case "bookshelfEdit": showingBookshelfEdit = true
            case "bookshelfSort": showingBookshelfSort = true
            case "fileImport": showingFileImport = true
            case "statistics": showingStatistics = true
            case "colorManager": showingColorManager = true
            case "settings": showingSettings = true
            case "bookSource": showingBookSource = true
            case "bookSea": showingBookSea = true
            case "contentFilter": showingContentFilter = true
            case "my": print("我的")
            case "incentive": print("激励视频")
            default: break
            }
        }
    }
}

struct SidebarMenuItem: Identifiable {
    let id: String
    let icon: String
    let title: String
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
