import SwiftUI

struct LibraryView: View {
    @State private var selectedTab = 0
    @StateObject private var bookManager = LocalBookManager.shared
    @StateObject private var groupManager = BookGroupManager.shared
    @EnvironmentObject var bookStore: BookStore
    @EnvironmentObject var sourceStore: SourceStore
    
    @State private var showingImport = false
    @State private var showingGroupManager = false
    @State private var showingNewGroupSheet = false
    @State private var showingGroupSettings = false
    @State private var selectedBook: Book?
    @State private var showingGroupDetail: BookGroup?
    @State private var showingLockedGroup: BookGroup?
    @State private var showingSearch = false
    @State private var showingSourceImport = false
    @State private var showingSourceEditor = false
    @State private var editingSource: BookSource?
    @State private var searchText = ""
    @State private var importText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("类型", selection: $selectedTab) {
                    Text("本地").tag(0)
                    Text("书源").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if selectedTab == 0 {
                    localBooksContent
                } else {
                    sourceManagementContent
                }
            }
            .navigationTitle("本地")
        }
    }
    
    private var localBooksContent: some View {
        VStack(spacing: 0) {
            if showingSearch {
                searchBar
            }
            
            groupListView
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showingSearch.toggle() }) {
                    Image(systemName: showingSearch ? "xmark" : "magnifyingglass")
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { showingGroupManager = true }) {
                    Image(systemName: "folder.badge.gearshape")
                }
                
                Button(action: { showingGroupSettings = true }) {
                    Image(systemName: "slider.horizontal.3")
                }
                
                Button(action: { showingNewGroupSheet = true }) {
                    Image(systemName: "folder.badge.plus")
                }
                
                Menu {
                    Button(action: { showingImport = true }) {
                        Label("导入书籍", systemImage: "book")
                    }
                    Button(action: { showingSourceImport = true }) {
                        Label("导入书源", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingImport) {
            FileImportView()
        }
        .sheet(isPresented: $showingSourceImport) {
            importSourceSheet
        }
        .sheet(isPresented: $showingGroupManager) {
            GroupManagementView()
        }
        .sheet(isPresented: $showingGroupSettings) {
            GroupSettingsView()
        }
        .sheet(isPresented: $showingNewGroupSheet) {
            NewGroupSheet()
        }
        .sheet(item: $showingGroupDetail) { group in
            GroupDetailView(group: group)
        }
        .sheet(item: $showingLockedGroup) { group in
            LockUnlockView(groupId: group.id, onSuccess: {
                showingLockedGroup = nil
                selectedGroup = group
            }, onCancel: {
                showingLockedGroup = nil
            })
        }
        .sheet(item: $selectedBook) { book in
            EnhancedBookDetailView(book: book)
        }
        .sheet(isPresented: $showingSourceEditor) {
            SourceEditorView(source: editingSource)
        }
        .sheet(isPresented: $showingSourceImport) {
            sourceImportSheet
        }
    }
    
    private var sourceManagementContent: some View {
        List {
            ForEach(sourceStore.bookSources) { source in
                sourceRow(source)
                    .swipeActions(edge: .leading) {
                        Button {
                            editingSource = source
                            showingSourceEditor = true
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            sourceStore.removeSource(source)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        
                        Button {
                            sourceStore.toggleSourceEnabled(source)
                        } label: {
                            Label(source.isEnabled ? "禁用" : "启用", systemImage: source.isEnabled ? "pause" : "play")
                        }
                        .tint(source.isEnabled ? .orange : .green)
                    }
            }
        }
        .listStyle(.plain)
        .overlay {
            if sourceStore.bookSources.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("暂无书源")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Button("新建书源") {
                        editingSource = nil
                        showingSourceEditor = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button(action: { editingSource = nil; showingSourceEditor = true }) {
                        Label("新建书源", systemImage: "plus")
                    }
                    Button(action: { showingSourceImport = true }) {
                        Label("导入书源", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("\(sourceStore.bookSources.count) 个书源")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func sourceRow(_ source: BookSource) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(source.name)
                        .font(.system(size: 16, weight: .medium))
                    
                    if !source.isEnabled {
                        Text("已禁用")
                            .font(.system(size: 11))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                    }
                }
                
                Text(source.url)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text(source.type.displayName)
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    Text("权重: \(source.weight)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(source.isEnabled ? 1.0 : 0.6)
    }
    
    private var importSourceSheet: some View {
        NavigationView {
            VStack {
                TextEditor(text: $importText)
                    .font(.system(size: 14))
                    .padding()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("支持格式:")
                        .font(.system(size: 14, weight: .medium))
                    Text("• Legado 书源 JSON")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("• 网络链接")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
            }
            .navigationTitle("导入书源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showingSourceImport = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("导入") {
                        let count = sourceStore.importBookSources(from: importText)
                        print("成功导入 \(count) 个书源")
                        importText = ""
                        showingSourceImport = false
                    }
                    .disabled(importText.isEmpty)
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索书籍", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }
    
    private var groupListView: some View {
        List {
            ForEach(filteredGroups) { group in
                GroupRowView(
                    group: group,
                    onTap: { handleGroupTap(group) },
                    onDelete: { handleDeleteGroup(group) }
                )
            }
        }
        .listStyle(.plain)
        .overlay {
            if groupManager.filteredGroups.isEmpty {
                emptyView
            }
        }
    }
    
    private var filteredGroups: [BookGroup] {
        var groups = groupManager.filteredGroups
        
        if !searchText.isEmpty {
            groups = groups.map { group in
                var filtered = group
                filtered.bookIds = group.bookIds.filter { bookId in
                    if let book = bookStore.books.first(where: { $0.id == bookId }) {
                        return book.name.localizedCaseInsensitiveContains(searchText) ||
                               book.author.localizedCaseInsensitiveContains(searchText)
                    }
                    return false
                }
                return filtered
            }.filter { !$0.bookIds.isEmpty }
        }
        
        return groups
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("暂无书籍")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("点击右上角按钮导入书籍或创建分组")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func handleGroupTap(_ group: BookGroup) {
        if group.isLocked {
            showingLockedGroup = group
        } else {
            selectedGroup = group
            showingGroupDetail = group
        }
    }
    
    private func handleDeleteGroup(_ group: BookGroup) {
        groupManager.deleteGroup(group)
    }
}
