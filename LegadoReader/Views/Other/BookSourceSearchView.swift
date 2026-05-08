import SwiftUI

struct BookSourceSearchView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var searchHistory: [String] = []
    @State private var selectedMatchType = "匹配"
    @State private var showMatchMenu = false
    @State private var showSpecifiedSource = false
    @State private var showBookSea = false
    @State private var selectedSources: [String] = []
    
    private let matchTypes = [
        MatchType(id: "raw", name: "原始", description: "不过滤"),
        MatchType(id: "containKey", name: "含键", description: "书名或作者包含关键词"),
        MatchType(id: "contain", name: "包含", description: "书名或作者与关键词相互包含"),
        MatchType(id: "match", name: "匹配", description: "书名或作者与关键词相同"),
    ]
    
    private let hotKeywords = ["魔域", "全球高武", "剑来", "元尊", "圣墟", "三寸人间", "诡秘之主", "全职法师", "无限恐怖"]
    
    private let bookSources = [
        "笔趣 biqge", "啃书网", "新无限", "2k小说站", "69好书 -源登陆再搜",
        "69@shux.co", "69书吧 shux", "Rmy精华书阁", "Rmy爱下api", "Rmy江南小说网",
        "Rmy骑士小说", "Rmy-69@69shuba", "Rmy-69好书", "Rmy-69书吧shux",
        "笔趣 bi-api", "笔趣 api", "番茄新书海YD", "番茄新书海ZC贰",
        "爱下网页版", "久久小说 @jjxsw", "猫眼API壹", "猫眼API叁",
        "手机小说网", "值得阅读-多来源", "全本qb5io", "蜜蜂中文ID搜",
        "猫眼API贰", "群小说网", "书海阁", "篱笆好文学", "Rmy聚合书库-多来源"
    ]
    
    private let bookSeaSources = [
        "2k小说站", "新无限", "啃书网", "笔趣 biqge", "篱笆好文学",
        "Rmy-69书吧 shux", "Rmy蓝海搜书-多来源", "Rmy精华书阁", "笔趣 bi-api",
        "Rmy-69好书", "Rmy江南小说网", "Rmy-69@69shuba", "69好书 -源登陆再搜"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                
                if showMatchMenu {
                    matchTypeMenu
                }
                
                ScrollView {
                    VStack(spacing: 20) {
                        hotKeywordsSection
                        
                        searchHistorySection
                    }
                    .padding()
                }
            }
            .navigationBarTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.white)
                    }
                }
            }
            .background(Color(.systemBackground))
            .sheet(isPresented: $showSpecifiedSource) {
                SpecifiedSourceView(selectedSources: $selectedSources)
            }
            .sheet(isPresented: $showBookSea) {
                BookSeaView()
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Button(action: { showMatchMenu.toggle() }) {
                HStack(spacing: 4) {
                    Text(selectedMatchType)
                        .foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red)
            .cornerRadius(8)
            
            TextField("请输入书名或作者名", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .placeholder(when: searchText.isEmpty) {
                    Text("请输入书名或作者名")
                        .foregroundColor(.white.opacity(0.7))
                }
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Button("指定源") {
                showSpecifiedSource = true
            }
            .foregroundColor(.white)
            
            Button("书海") {
                showBookSea = true
            }
            .foregroundColor(.white)
        }
        .padding(8)
        .background(Color.red)
    }
    
    private var matchTypeMenu: some View {
        VStack(spacing: 0) {
            ForEach(matchTypes) { type in
                Button(action: {
                    selectedMatchType = type.name
                    showMatchMenu = false
                }) {
                    HStack {
                        Text("\(type.name):\(type.description)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if selectedMatchType == type.name {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                
                Divider()
            }
        }
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 4)
        .padding(.horizontal, 16)
    }
    
    private var hotKeywordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("热门关键词")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Button(action: {}) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.secondary)
                }
            }
            
            WrapView(items: hotKeywords) { keyword in
                Button(action: { searchText = keyword }) {
                    Text(keyword)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                }
            }
        }
    }
    
    private var searchHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("搜索历史")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Button(action: { searchHistory.removeAll() }) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                }
            }
            
            if searchHistory.isEmpty {
                Text("暂无搜索记录")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 16)
            } else {
                ForEach(searchHistory, id: \.self) { history in
                    HStack {
                        Text(history)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("5天前")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .onTapGesture {
                        searchText = history
                    }
                }
            }
        }
    }
}

struct MatchType: Identifiable {
    let id: String
    let name: String
    let description: String
}

struct SpecifiedSourceView: View {
    @Binding var selectedSources: [String]
    @Environment(\.dismiss) var dismiss
    
    private let bookSources = [
        ("笔趣 biqge", true), ("啃书网", true), ("新无限", true),
        ("2k小说站", true), ("69好书 -源登陆再搜", true),
        ("69@shux.co", true), ("69书吧 shux", true),
        ("Rmy精华书阁", false), ("Rmy爱下api", false), ("Rmy江南小说网", false),
        ("Rmy骑士小说", false), ("Rmy-69@69shuba", false),
        ("Rmy-69好书", false), ("Rmy-69书吧shux", false),
        ("笔趣 bi-api", true), ("笔趣 api", true),
        ("番茄新书海YD", true), ("番茄新书海ZC贰", true),
        ("爱下网页版", true), ("久久小说 @jjxsw", true),
        ("猫眼API壹", true), ("猫眼API叁", true),
        ("手机小说网", true), ("值得阅读-多来源", true),
        ("全本qb5io", true), ("蜜蜂中文ID搜", true),
        ("猫眼API贰", true), ("群小说网", true), ("书海阁", true),
        ("篱笆好文学", true), ("Rmy聚合书库-多来源", false)
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                
                Text("可用搜索源名称(可指定仅搜索选中源)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                ScrollView {
                    WrapView(items: bookSources) { source in
                        Button(action: {
                            if selectedSources.contains(source.0) {
                                selectedSources.removeAll { $0 == source.0 }
                            } else {
                                selectedSources.append(source.0)
                            }
                        }) {
                            HStack(spacing: 4) {
                                if source.1 {
                                    Text("🥬🐷")
                                }
                                Text(source.0)
                            }
                            .font(.subheadline)
                            .foregroundColor(selectedSources.contains(source.0) ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedSources.contains(source.0) ? Color.red : Color(.systemGray6))
                            .cornerRadius(20)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("指定搜索源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            TextField("显示指定源", text: .constant(""))
                .textFieldStyle(.roundedBorder)
                .disabled(true)
            
            Button(action: {}) {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct BookSeaView: View {
    @Environment(\.dismiss) var dismiss
    
    private let bookSeaSources = [
        ("2k小说站", true), ("新无限", true), ("啃书网", true),
        ("笔趣 biqge", true), ("篱笆好文学", true),
        ("Rmy-69书吧 shux", false), ("Rmy蓝海搜书-多来源", false),
        ("Rmy精华书阁", false), ("笔趣 bi-api", true),
        ("Rmy-69好书", false), ("Rmy江南小说网", false),
        ("Rmy-69@69shuba", false), ("69好书 -源登陆再搜", true)
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                
                Text("书海无涯，只有书源配置了，才会在这里展示")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Text("列表支持左滑操作，长按可进入编辑状态")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                List {
                    ForEach(bookSeaSources, id: \.0) { source in
                        HStack {
                            HStack(spacing: 4) {
                                if source.1 {
                                    Text("🥬🐷")
                                }
                                Text(source.0)
                            }
                            .font(.headline)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .swipeActions(edge: .leading) {
                            Button("禁用") {
                                print("禁用 \(source.0)")
                            }
                            .tint(.red)
                            
                            Button("置顶") {
                                print("置顶 \(source.0)")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
            .navigationTitle("书海无涯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("编辑") {
                        print("进入编辑模式")
                    }
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            TextField("输入关键词用于过滤书海", text: .constant(""))
                .textFieldStyle(.roundedBorder)
        }
        .padding()
    }
}

struct WrapView<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    
    init(items: [Item], content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .alignmentGuide(.leading, computeValue: { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height
                        }
                        let result = width
                        if item == items.last {
                            width = 0
                        } else {
                            width -= dimension.width + 8
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if item == items.last {
                            height = 0
                        }
                        return result
                    })
            }
        }
    }
}

extension View {
    func placeholder<Content: View>(when shouldShow: Bool, alignment: Alignment = .leading, @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}