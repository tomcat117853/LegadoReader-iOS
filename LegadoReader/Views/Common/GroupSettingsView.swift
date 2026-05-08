import SwiftUI

struct GroupSettingsView: View {
    @ObservedObject var groupManager = BookGroupManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedGroup: BookGroup?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(groupManager.groups) { group in
                        GroupSettingsRow(group: group) {
                            selectedGroup = group
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            groupManager.deleteGroup(groupManager.groups[index])
                        }
                    }
                    .onMove { source, destination in
                        groupManager.moveGroup(from: source, to: destination)
                    }
                } header: {
                    Text("分组列表")
                } footer: {
                    Text("向左滑动删除分组，长按拖动排序")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("书架分组设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .sheet(item: $selectedGroup) { group in
                GroupLayoutSettingsView(group: group)
            }
        }
    }
}

struct GroupSettingsRow: View {
    let group: BookGroup
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: group.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Label(group.layoutStyle.displayName, systemImage: group.layoutStyle.icon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Label(group.getSortName(), systemImage: group.getSortIcon())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text("\(group.bookCount)本")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

struct GroupLayoutSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var group: BookGroup
    @ObservedObject var groupManager = BookGroupManager.shared
    
    init(group: BookGroup) {
        _group = State(initialValue: group)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("分组信息") {
                    HStack {
                        Image(systemName: group.icon)
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                            .frame(width: 60, height: 60)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("\(group.bookCount) 本书籍")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("布局设置") {
                    ForEach(BookGroup.LayoutStyle.allCases, id: \.self) { style in
                        Button(action: {
                            group.layoutStyle = style
                        }) {
                            HStack {
                                Image(systemName: style.icon)
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .frame(width: 40)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(style.displayName)
                                        .foregroundColor(.primary)
                                    Text(layoutDescription(for: style))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if group.layoutStyle == style {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    if group.layoutStyle == .grid {
                        Stepper("列数: \(group.columnsCount)", value: $group.columnsCount, in: 2...5)
                            .padding(.vertical, 4)
                    }
                }
                
                Section("排序设置") {
                    ForEach(sortOptions, id: \.0) { option in
                        Button(action: {
                            group.sortOption = option.0
                        }) {
                            HStack {
                                Image(systemName: option.2)
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                Text(option.1)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if group.sortOption == option.0 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    Toggle("升序排列", isOn: $group.sortAscending)
                        .tint(.green)
                }
                
                Section("预览") {
                    GroupLayoutPreview(group: group)
                        .frame(height: 200)
                        .listRowInsets(EdgeInsets())
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("分组设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var sortOptions: [(String, String, String)] {
        [
            ("namePinyin", "按书名拼音", "textformat.abc"),
            ("authorPinyin", "按作者拼音", "person"),
            ("lastRead", "最近阅读", "clock"),
            ("addedTime", "添加时间", "calendar"),
            ("name", "书名排序", "textformat")
        ]
    }
    
    private func layoutDescription(for style: BookGroup.LayoutStyle) -> String {
        switch style {
        case .grid: return "显示书籍封面网格"
        case .list: return "显示书籍列表"
        case .cover: return "大尺寸封面展示"
        }
    }
    
    private func saveChanges() {
        groupManager.updateGroupInfo(group.id, editInfo: GroupEditInfo(from: group))
    }
}

struct GroupLayoutPreview: View {
    let group: BookGroup
    
    var body: some View {
        GeometryReader { geometry in
            switch group.layoutStyle {
            case .grid:
                gridPreview(geometry: geometry)
            case .list:
                listPreview(geometry: geometry)
            case .cover:
                coverPreview(geometry: geometry)
            }
        }
    }
    
    private func gridPreview(geometry: GeometryProxy) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: group.columnsCount)
        
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(3/4, contentMode: .fit)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.5))
                            .frame(height: 12)
                            .frame(maxWidth: 60)
                    }
                }
            }
            .padding()
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func listPreview(geometry: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 70)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.5))
                            .frame(height: 14)
                            .frame(maxWidth: 120)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 12)
                            .frame(maxWidth: 80)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func coverPreview(geometry: GeometryProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(0..<5, id: \.self) { _ in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 160)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 100, height: 12)
                    }
                }
            }
            .padding()
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct QuickGroupLayoutToggle: View {
    @Binding var layoutStyle: BookGroup.LayoutStyle
    let compact: Bool
    
    var body: some View {
        if compact {
            Menu {
                ForEach(BookGroup.LayoutStyle.allCases, id: \.self) { style in
                    Button(action: {
                        layoutStyle = style
                    }) {
                        Label(style.displayName, systemImage: style.icon)
                    }
                }
            } label: {
                Image(systemName: layoutStyle.icon)
                    .font(.title3)
            }
        } else {
            HStack(spacing: 16) {
                ForEach(BookGroup.LayoutStyle.allCases, id: \.self) { style in
                    Button(action: {
                        layoutStyle = style
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: style.icon)
                                .font(.title2)
                            Text(style.displayName)
                                .font(.caption2)
                        }
                        .foregroundColor(layoutStyle == style ? .blue : .secondary)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(layoutStyle == style ? Color.blue.opacity(0.1) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(layoutStyle == style ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
            }
        }
    }
}
