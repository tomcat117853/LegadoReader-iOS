import SwiftUI

struct ReaderSettingsMenuView: View {
    @Environment(\.dismiss) var dismiss
    
    let menuItems = [
        MenuItem(id: "simplified", icon: "简", title: "原简繁随"),
        MenuItem(id: "cloudProgress", icon: "cloud.rain", title: "云端进度"),
        MenuItem(id: "addBookmark", icon: "bookmark.plus", title: "添加书签"),
        MenuItem(id: "bookDetail", icon: "book", title: "书籍详情"),
        MenuItem(id: "search", icon: "magnifyingglass", title: "全文搜索"),
        MenuItem(id: "contentFilter", icon: "funnel", title: "内容过滤"),
        MenuItem(id: "contentEdit", icon: "doc.text", title: "内容编辑"),
        MenuItem(id: "titleFormat", icon: "<>", title: "标题格式"),
        MenuItem(id: "layoutEnhance", icon: "textformat", title: "排版强化"),
        MenuItem(id: "readingTrack", icon: "scribble", title: "阅读轨迹"),
        MenuItem(id: "cssStyle", icon: "CSS", title: "原文样式"),
        MenuItem(id: "imageAdaptive", icon: "photo", title: "图随境变"),
        MenuItem(id: "coverTop", icon: "arrow.up.to.line", title: "题图置顶"),
        MenuItem(id: "functionConfig", icon: "gear", title: "功能配置"),
        MenuItem(id: "incentiveVideo", icon: "hand.thumbsup", title: "激励视频"),
        MenuItem(id: "bookStats", icon: "barchart", title: "书籍统计"),
        MenuItem(id: "moreSettings", icon: "ellipsis", title: "更多设置"),
        MenuItem(id: "textMenu", icon: "list.bullet", title: "正文菜单"),
        MenuItem(id: "lockColor", icon: "droplet", title: "锁定颜色"),
        MenuItem(id: "markAppearance", icon: "pin", title: "标记外观"),
        MenuItem(id: "textMargin", icon: "square.grid.3x3", title: "原文边距"),
    ]
    
    @State private var selectedItem: String = "simplified"
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 24) {
                    ForEach(menuItems) { item in
                        Button(action: {
                            selectedItem = item.id
                            handleMenuItem(item.id)
                        }) {
                            VStack(spacing: 8) {
                                if item.icon == "简" {
                                    Text(item.icon)
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .frame(width: 56, height: 56)
                                        .background(selectedItem == item.id ? Color.green : Color(.systemGray5))
                                        .foregroundColor(selectedItem == item.id ? Color.white : Color(.systemGray4))
                                        .cornerRadius(28)
                                } else if item.icon == "CSS" {
                                    Text(item.icon)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .frame(width: 56, height: 56)
                                        .background(Color(.systemGray5))
                                        .foregroundColor(Color(.systemGray4))
                                        .cornerRadius(28)
                                } else if item.icon == "<>" {
                                    Text(item.icon)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .frame(width: 56, height: 56)
                                        .background(Color(.systemGray5))
                                        .foregroundColor(Color(.systemGray4))
                                        .cornerRadius(28)
                                } else {
                                    Image(systemName: item.icon)
                                        .font(.title)
                                        .frame(width: 56, height: 56)
                                        .background(Color(.systemGray5))
                                        .foregroundColor(Color(.systemGray4))
                                        .cornerRadius(28)
                                }
                                
                                Text(item.title)
                                    .font(.caption)
                                    .foregroundColor(Color(.systemGray4))
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(hex: "1B5E20") ?? Color.green)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func handleMenuItem(_ id: String) {
        switch id {
        case "contentFilter":
            print("打开内容过滤")
        case "bookDetail":
            print("打开书籍详情")
        case "addBookmark":
            print("添加书签")
        case "search":
            print("全文搜索")
        case "bookStats":
            print("书籍统计")
        case "moreSettings":
            print("更多设置")
        default:
            print("点击: \(id)")
        }
    }
}

struct MenuItem: Identifiable {
    let id: String
    let icon: String
    let title: String
}

struct ReaderSettingsMenuView_Previews: PreviewProvider {
    static var previews: some View {
        ReaderSettingsMenuView()
    }
}
