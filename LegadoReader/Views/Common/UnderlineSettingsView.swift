import SwiftUI

struct UnderlineSettingsView: View {
    @StateObject private var underlineManager = UnderlineManager.shared
    @State private var selectedFilter: UnderlineFilter = .all
    @State private var searchText = ""
    
    enum UnderlineFilter: String, CaseIterable {
        case all = "全部"
        case today = "今天"
        case thisWeek = "本周"
        case withNotes = "有笔记"
    }
    
    var filteredUnderlines: [UnderlineManager.Underline] {
        var filtered = underlineManager.underlines
        
        switch selectedFilter {
        case .all:
            break
        case .today:
            filtered = filtered.filter {
                Calendar.current.isDate($0.createdTime, inSameDayAs: Date())
            }
        case .thisWeek:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            filtered = filtered.filter { $0.createdTime > weekAgo }
        case .withNotes:
            filtered = filtered.filter { !$0.note.isEmpty }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { underline in
                underline.text.contains(searchText) ||
                underline.note.contains(searchText)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("筛选", selection: $selectedFilter) {
                    ForEach(UnderlineFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if filteredUnderlines.isEmpty {
                    EmptyUnderlineView()
                } else {
                    List {
                        Section {
                            StatisticsView(statistics: underlineManager.getUnderlineStatistics())
                        } header: {
                            Text("统计信息")
                        }
                        
                        Section {
                            ForEach(filteredUnderlines) { underline in
                                UnderlineRowView(underline: underline)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            underlineManager.removeUnderline(underline)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        NavigationLink(destination: EditUnderlineView(underline: underline)) {
                                            Button {
                                            } label: {
                                                Label("编辑", systemImage: "pencil")
                                            }
                                            .tint(.blue)
                                        }
                                    }
                            }
                        } header: {
                            Text("下划线列表 (\(filteredUnderlines.count))")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("下划线管理")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索下划线")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            underlineManager.clearAllUnderlines()
                        }) {
                            Label("清空全部下划线", systemImage: "trash")
                        }
                        .foregroundColor(.red)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
}

struct StatisticsView: View {
    let statistics: UnderlineManager.UnderlineStatistics
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                StatItem(title: "总下划线", value: "\(statistics.totalUnderlines)", color: .blue)
                StatItem(title: "涉及书籍", value: "\(statistics.booksWithUnderlines)", color: .green)
            }
            HStack {
                StatItem(title: "涉及章节", value: "\(statistics.chaptersWithUnderlines)", color: .orange)
                StatItem(title: "今日添加", value: "\(statistics.todayUnderlines)", color: .purple)
            }
        }
        .padding(.vertical, 8)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct UnderlineRowView: View {
    let underline: UnderlineManager.Underline
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(hex: underline.color.hexColor) ?? .blue)
                    .frame(width: 8, height: 8)
                
                Text(underline.style.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                
                Spacer()
                
                Text(underline.createdTime, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(underline.text)
                    .font(.subheadline)
                    .lineLimit(2)
                    .underline(
                        style: getTextDecorationStyle(underline.style),
                        color: Color(hex: underline.color.hexColor) ?? .blue
                    )
            }
            
            HStack {
                Text("位置: \(underline.startOffset) - \(underline.endOffset)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            if !underline.note.isEmpty {
                Text(underline.note)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .lineLimit(2)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func getTextDecorationStyle(_ style: UnderlineManager.Underline.UnderlineStyle) -> Text.DecorationStyle {
        switch style {
        case .single: return .single
        case .double: return .double
        case .thick: return .thick
        case .dotted: return .style(.init(pattern: .dot))
        case .wavy: return .style(.init(pattern: .wave))
        }
    }
}

struct EmptyUnderlineView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "underline")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("暂无下划线")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("在阅读时选择文本添加下划线标记")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EditUnderlineView: View {
    let underline: UnderlineManager.Underline
    @StateObject private var underlineManager = UnderlineManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var note: String = ""
    @State private var selectedStyle: UnderlineManager.Underline.UnderlineStyle = .single
    @State private var selectedColor: UnderlineManager.Underline.UnderlineColor = .blue
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("书籍")
                    Spacer()
                    Text(underline.bookId)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Text("章节")
                    Spacer()
                    Text(underline.chapterId)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Text("位置")
                    Spacer()
                    Text("\(underline.startOffset) - \(underline.endOffset)")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("位置信息")
            }
            
            Section {
                TextEditor(text: $note)
                    .frame(minHeight: 80)
            } header: {
                Text("笔记")
            }
            
            Section("下划线样式") {
                ForEach(UnderlineManager.Underline.UnderlineStyle.allCases, id: \.self) { style in
                    Button(action: {
                        selectedStyle = style
                    }) {
                        HStack {
                            Text("测试文本")
                                .underline(
                                    style: getTextDecorationStyle(style),
                                    color: Color(hex: selectedColor.hexColor) ?? .blue
                                )
                            
                            Text(style.displayName)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedStyle == style {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            Section("下划线颜色") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                    ForEach(UnderlineManager.Underline.UnderlineColor.allCases, id: \.self) { color in
                        Button(action: {
                            selectedColor = color
                        }) {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: color.hexColor) ?? .blue)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 2)
                                    )
                                
                                Text(color.displayName)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(underline.text)
                        .font(.body)
                        .underline(
                            style: getTextDecorationStyle(selectedStyle),
                            color: Color(hex: selectedColor.hexColor) ?? .blue
                        )
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            } header: {
                Text("预览")
            }
            
            Section {
                Button("保存修改") {
                    saveChanges()
                }
                .foregroundColor(.blue)
                
                Button("删除此下划线") {
                    underlineManager.removeUnderline(underline)
                    dismiss()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("编辑下划线")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            note = underline.note
            selectedStyle = underline.style
            selectedColor = underline.color
        }
    }
    
    private func getTextDecorationStyle(_ style: UnderlineManager.Underline.UnderlineStyle) -> Text.DecorationStyle {
        switch style {
        case .single: return .single
        case .double: return .double
        case .thick: return .thick
        case .dotted: return .style(.init(pattern: .dot))
        case .wavy: return .style(.init(pattern: .wave))
        }
    }
    
    private func saveChanges() {
        underlineManager.updateUnderlineNote(underline, note: note)
        underlineManager.updateUnderlineStyle(underline, style: selectedStyle)
        underlineManager.updateUnderlineColor(underline, color: selectedColor)
        dismiss()
    }
}

struct UnderlineSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        UnderlineSettingsView()
    }
}
