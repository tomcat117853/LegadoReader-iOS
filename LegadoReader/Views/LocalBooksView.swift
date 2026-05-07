import SwiftUI

struct LocalBooksView: View {
    @StateObject private var bookManager = LocalBookManager.shared
    @StateObject private var groupManager = BookGroupManager.shared
    @StateObject private var bookStore = BookStore.shared
    @State private var showingImport = false
    @State private var showingGroupManager = false
    @State private var showingNewGroupSheet = false
    @State private var selectedBook: Book?
    @State private var selectedGroup: BookGroup?
    @State private var showingGroupDetail: BookGroup?
    @State private var showingLockedGroup: BookGroup?
    @State private var showingSearch = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if showingSearch {
                    searchBar
                }
                
                groupListView
            }
            .navigationTitle("本地书籍")
            .navigationBarTitleDisplayMode(.inline)
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
                    
                    Button(action: { showingNewGroupSheet = true }) {
                        Image(systemName: "folder.badge.plus")
                    }
                    
                    Button(action: { showingImport = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingImport) {
                // Import sheet
            }
            .sheet(isPresented: $showingGroupManager) {
                GroupManagementView()
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

struct GroupRowView: View {
    let group: BookGroup
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @StateObject private var bookStore = BookStore.shared
    @State private var books: [Book] = []
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(groupColor.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: group.icon)
                            .font(.system(size: 28))
                            .foregroundColor(groupColor)
                        
                        if group.isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                                .offset(x: 18, y: -18)
                        }
                        
                        if group.isHidden {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .offset(x: -18, y: -18)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("\(group.bookCount) 本书")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let description = group.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                
                if !books.isEmpty {
                    bookCoverRow
                }
            }
            .padding(.vertical, 8)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
        .onAppear {
            loadBooks()
        }
    }
    
    private var groupColor: Color {
        switch group.icon {
        case "star.fill": return .yellow
        case "heart.fill": return .red
        case "bookmark.fill": return .green
        case "flag.fill": return .orange
        case "crown.fill": return .purple
        default: return .blue
        }
    }
    
    private var bookCoverRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(books.prefix(6)) { book in
                    VStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 40, height: 56)
                            
                            if let cover = book.cover, let url = URL(string: cover) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Image(systemName: "book.fill")
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 40, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            } else {
                                Image(systemName: "book.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        if book.progress > 0 {
                            ProgressView(value: book.progress)
                                .progressViewStyle(.linear)
                                .frame(width: 40)
                                .tint(.blue)
                        }
                    }
                }
            }
            .padding(.leading, 76)
        }
    }
    
    private func loadBooks() {
        books = group.bookIds.compactMap { bookId in
            bookStore.books.first { $0.id == bookId }
        }
    }
}

struct GroupManagementView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var groupManager = BookGroupManager.shared
    @State private var showingNewGroup = false
    @State private var selectedGroup: BookGroup?
    @State private var showingEditSheet = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(groupManager.groups) { group in
                    Button(action: {
                        selectedGroup = group
                        showingEditSheet = true
                    }) {
                        HStack {
                            Image(systemName: group.icon)
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(group.name)
                                        .foregroundColor(.primary)
                                    
                                    if group.isLocked {
                                        Image(systemName: "lock.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    
                                    if group.isHidden {
                                        Image(systemName: "eye.slash.fill")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Text("\(group.bookCount) 本书")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            groupManager.deleteGroup(group)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: moveGroups)
            }
            .listStyle(.plain)
            .navigationTitle("分组管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewGroup = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewGroup) {
                NewGroupSheet()
            }
            .sheet(isPresented: $showingEditSheet) {
                if let group = selectedGroup {
                    GroupDetailView(group: group)
                }
            }
        }
    }
    
    private func moveGroups(from source: IndexSet, to destination: Int) {
        groupManager.moveGroup(from: source, to: destination)
    }
}
