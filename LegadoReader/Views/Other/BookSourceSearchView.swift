import SwiftUI

struct BookSourceSearchView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var searchHistory: [String] = []
    @State private var selectedMatchType = "匹配"
    
    private let matchTypes = ["匹配", "书名", "作者", "标签"]
    private let hotKeywords = ["魔域", "全球高武", "剑来", "元尊", "圣墟", "三寸人间", "诡秘之主", "全职法师", "无限恐怖"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                
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
        }
        .navigationViewStyle(.stack)
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $selectedMatchType) {
                ForEach(matchTypes, id: \.self) { type in
                    Text(type)
                        .foregroundColor(.white)
                }
            }
            .pickerStyle(.menu)
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
                print("选择指定源")
            }
            .foregroundColor(.white)
            
            Button("书海") {
                print("进入书海")
            }
            .foregroundColor(.white)
        }
        .padding(8)
        .background(Color.red)
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