import SwiftUI

struct GroupDetailView: View {
    @StateObject private var groupManager = BookGroupManager.shared
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingLockAlert = false
    @State private var showingHideAlert = false
    @State private var showingAddBookSheet = false
    @State private var editInfo: GroupEditInfo
    @State private var showingSortMenu = false
    @State private var showingFilterSheet = false
    
    let group: BookGroup
    let onDismiss: () -> Void
    
    init(group: BookGroup, onDismiss: @escaping () -> Void = {}) {
        self.group = group
        self.onDismiss = onDismiss
        self._editInfo = State(initialValue: GroupEditInfo(from: group))
    }
    
    var body: some View {
        NavigationView {
            List {
                groupInfoSection
                securitySection
                booksSection
                actionSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("分组详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("编辑") {
                        showingEditSheet = true
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                GroupEditSheet(group: group, editInfo: $editInfo, onSave: { updatedInfo in
                    groupManager.updateGroupInfo(group.id, editInfo: updatedInfo)
                })
            }
            .alert("确认删除", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    groupManager.deleteGroup(group)
                    onDismiss()
                }
            } message: {
                Text("确定要删除分组 \"\(group.name)\" 吗？分组内的书籍不会被删除。")
            }
            .alert("确认加锁", isPresented: $showingLockAlert) {
                Button("取消", role: .cancel) {}
                Button(group.isLocked ? "解锁" : "加锁", role: group.isLocked ? .cancel : .destructive) {
                    groupManager.toggleLock(group)
                }
            } message: {
                Text(group.isLocked ? "确定要解锁此分组吗？" : "确定要锁定此分组吗？锁定后需要验证才能访问。")
            }
            .alert("确认隐藏", isPresented: $showingHideAlert) {
                Button("取消", role: .cancel) {}
                Button(group.isHidden ? "显示" : "隐藏", role: group.isHidden ? .cancel : .destructive) {
                    groupManager.toggleHidden(group)
                }
            } message: {
                Text(group.isHidden ? "确定要显示此分组吗？" : "确定要隐藏此分组吗？隐藏后将在书架中不可见。")
            }
            .sheet(isPresented: $showingFilterSheet) {
                GroupSortFilterSheet()
            }
        }
    }
    
    private var groupInfoSection: some View {
        Section {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: group.icon)
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Image(systemName: "number")
                            .font(.caption)
                        Text("顺序: \(group.order + 1)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "books.vertical")
                            .font(.caption)
                        Text("\(group.bookCount) 本书")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if group.isLocked {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.orange)
                    }
                    if group.isHidden {
                        Image(systemName: "eye.slash.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.vertical, 8)
            
            if let description = group.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("描述")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(description)
                        .font(.body)
                }
                .padding(.vertical, 4)
            }
            
            HStack {
                Text("创建时间")
                    .foregroundColor(.secondary)
                Spacer()
                Text(group.createdTime.formatted(date: .abbreviated, time: .shortened))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("更新时间")
                    .foregroundColor(.secondary)
                Spacer()
                Text(group.updatedTime.formatted(date: .abbreviated, time: .shortened))
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("分组信息")
        }
    }
    
    private var securitySection: some View {
        Section {
            Button(action: { showingLockAlert = true }) {
                HStack {
                    Image(systemName: group.isLocked ? "lock.fill" : "lock.open")
                        .foregroundColor(group.isLocked ? .orange : .secondary)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading) {
                        Text(group.isLocked ? "已加锁" : "未加锁")
                            .foregroundColor(.primary)
                        Text(group.isLocked ? "点击解锁分组" : "点击锁定分组")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: { showingHideAlert = true }) {
                HStack {
                    Image(systemName: group.isHidden ? "eye.slash.fill" : "eye")
                        .foregroundColor(group.isHidden ? .gray : .secondary)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading) {
                        Text(group.isHidden ? "已隐藏" : "未隐藏")
                            .foregroundColor(.primary)
                        Text(group.isHidden ? "点击显示分组" : "点击隐藏分组")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("安全设置")
        }
    }
    
    private var booksSection: some View {
        Section {
            HStack {
                Text("书籍数量")
                Spacer()
                Text("\(group.bookCount)")
                    .foregroundColor(.secondary)
            }
            
            Button(action: { showingAddBookSheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    
                    Text("添加书籍到分组")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("书籍管理")
        }
    }
    
    private var actionSection: some View {
        Section {
            Button(action: { showingFilterSheet = true }) {
                HStack {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                    
                    Text("排序与筛选")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(groupManager.sortOption.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: { groupManager.duplicateGroup(group) }) {
                HStack {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                    
                    Text("复制分组")
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
            
            Button(action: { showingDeleteAlert = true }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .frame(width: 30)
                    
                    Text("删除分组")
                        .foregroundColor(.red)
                    
                    Spacer()
                }
            }
        }
    }
}

struct GroupEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var editInfo: GroupEditInfo
    @Binding var editInfoBinding: GroupEditInfo
    
    let group: BookGroup
    let onSave: (GroupEditInfo) -> Void
    
    @State private var showingIconPicker = false
    @State private var customName: String
    
    init(group: BookGroup, editInfo: Binding<GroupEditInfo>, onSave: @escaping (GroupEditInfo) -> Void) {
        self.group = group
        self._editInfoBinding = editInfo
        self._editInfo = State(initialValue: editInfo.wrappedValue)
        self.onSave = onSave
        self._customName = State(initialValue: editInfo.wrappedValue.name)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("名称")
                        Spacer()
                        TextField("分组名称", text: $editInfo.name)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("图标")
                        Spacer()
                        Button(action: { showingIconPicker = true }) {
                            HStack {
                                Image(systemName: editInfo.icon)
                                    .foregroundColor(.blue)
                                Text("选择图标")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                } header: {
                    Text("基本信息")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("描述")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("添加描述（可选）", text: Binding(
                            get: { editInfo.description ?? "" },
                            set: { editInfo.description = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                        .lineLimit(3...6)
                    }
                } header: {
                    Text("描述")
                }
                
                Section {
                    Toggle("加锁保护", isOn: $editInfo.isLocked)
                        .tint(.orange)
                    
                    Toggle("隐藏分组", isOn: $editInfo.isHidden)
                        .tint(.gray)
                } header: {
                    Text("安全设置")
                } footer: {
                    Text("加锁后访问分组需要验证。隐藏后分组将不在书架中显示。")
                }
                
                Section {
                    if let cover = editInfo.coverImage, !cover.isEmpty {
                        VStack {
                            AsyncImage(url: URL(string: cover)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 100)
                                    .cornerRadius(8)
                            } placeholder: {
                                Color.gray.opacity(0.2)
                                    .frame(height: 100)
                                    .cornerRadius(8)
                            }
                            
                            Button("清除封面") {
                                editInfo.coverImage = nil
                            }
                            .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text("封面图片URL")
                }
            }
            .navigationTitle("编辑分组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        editInfoBinding = editInfo
                        onSave(editInfo)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerSheet(selectedIcon: $editInfo.icon)
            }
        }
    }
}

struct IconPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedIcon: String
    
    let icons = [
        "folder.fill", "books.vertical.fill", "star.fill", "heart.fill",
        "book.fill", "bookmark.fill", "tag.fill", "flag.fill",
        "book.closed.fill", "newspaper.fill", "doc.fill", "archivebox.fill",
        "tray.fill", "square.stack.fill", "sparkles", "crown.fill",
        "diamond.fill", "bolt.fill", "flame.fill", "drop.fill",
        "moon.fill", "sun.max.fill", "cloud.fill", "snowflake",
        "leaf.fill", "tree.fill", "mountain.2.fill", "globe",
        "paintbrush.fill", "paintpalette.fill", "camera.fill", "photo.fill",
        "music.note", "headphones", "speaker.wave.2.fill", "waveform",
        "gamecontroller.fill", "ladybug.fill", "hare.fill", "tortoise.fill",
        "car.fill", "airplane", "bicycle", "figure.walk"
    ]
    
    let columns = [
        GridItem(.adaptive(minimum: 60))
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(icons, id: \.self) { icon in
                        Button(action: {
                            selectedIcon = icon
                            dismiss()
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(selectedIcon == icon ? .blue : .primary)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("选择图标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct GroupSortFilterSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var groupManager = BookGroupManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("排序方式", selection: $groupManager.sortOption) {
                        ForEach(GroupSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .onChange(of: groupManager.sortOption) { _, newValue in
                        groupManager.setSortOption(newValue)
                    }
                } header: {
                    Text("排序")
                }
                
                Section {
                    Toggle("显示已隐藏的分组", isOn: $groupManager.currentFilter.showHidden)
                    
                    Toggle("显示已锁定的分组", isOn: $groupManager.currentFilter.showLocked)
                } header: {
                    Text("筛选")
                }
                
                Section {
                    HStack {
                        TextField("搜索分组名称", text: $groupManager.currentFilter.searchText)
                    }
                } header: {
                    Text("搜索")
                }
                
                Section {
                    Button("重置筛选条件") {
                        groupManager.resetFilter()
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("排序与筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
