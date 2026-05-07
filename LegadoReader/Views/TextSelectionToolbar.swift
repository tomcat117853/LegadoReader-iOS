import SwiftUI

struct TextSelectionToolbar: View {
    let selectedText: String
    let onAddUnderline: () -> Void
    let onAddNote: () -> Void
    let onCopy: () -> Void
    let onShare: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text(selectedText)
                .font(.body)
                .lineLimit(2)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            HStack(spacing: 24) {
                ToolbarButton(
                    icon: "underline",
                    title: "下划线",
                    color: .blue,
                    action: onAddUnderline
                )
                
                ToolbarButton(
                    icon: "note.text",
                    title: "笔记",
                    color: .orange,
                    action: onAddNote
                )
                
                ToolbarButton(
                    icon: "doc.on.doc",
                    title: "复制",
                    color: .gray,
                    action: onCopy
                )
                
                ToolbarButton(
                    icon: "square.and.arrow.up",
                    title: "分享",
                    color: .green,
                    action: onShare
                )
                
                ToolbarButton(
                    icon: "xmark",
                    title: "取消",
                    color: .red,
                    action: onCancel
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
    }
}

struct ToolbarButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct UnderlineStylePicker: View {
    @Binding var selectedStyle: UnderlineManager.Underline.UnderlineStyle
    @Binding var selectedColor: UnderlineManager.Underline.UnderlineColor
    let previewText: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section("样式") {
                    ForEach(UnderlineManager.Underline.UnderlineStyle.allCases, id: \.self) { style in
                        Button(action: {
                            selectedStyle = style
                        }) {
                            HStack {
                                Text(previewText)
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
                
                Section("颜色") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                        ForEach(UnderlineManager.Underline.UnderlineColor.allCases, id: \.self) { color in
                            Button(action: {
                                selectedColor = color
                            }) {
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(hex: color.hexColor) ?? .blue)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
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
                
                Section("预览") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(previewText)
                            .font(.title3)
                            .underline(
                                style: getTextDecorationStyle(selectedStyle),
                                color: Color(hex: selectedColor.hexColor) ?? .blue
                            )
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
            }
            .navigationTitle("设置下划线")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认") {
                        onConfirm()
                    }
                    .fontWeight(.semibold)
                }
            }
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
}

struct UnderlineNoteSheet: View {
    let underline: UnderlineManager.Underline
    @StateObject private var underlineManager = UnderlineManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var note: String = ""
    @State private var selectedStyle: UnderlineManager.Underline.UnderlineStyle = .single
    @State private var selectedColor: UnderlineManager.Underline.UnderlineColor = .blue
    @State private var showingStylePicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("选中文本") {
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
                
                Section {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                } header: {
                    Text("添加笔记")
                } footer: {
                    Text("输入对这段文字的想法或注释")
                }
                
                Section("下划线样式") {
                    Button(action: {
                        showingStylePicker = true
                    }) {
                        HStack {
                            Text("样式")
                            Spacer()
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: selectedColor.hexColor) ?? .blue)
                                    .frame(width: 12, height: 12)
                                Text(selectedStyle.displayName)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section {
                    Button("保存笔记") {
                        saveNote()
                    }
                    .foregroundColor(.blue)
                    
                    Button("删除此下划线") {
                        underlineManager.removeUnderline(underline)
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("下划线笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingStylePicker) {
                UnderlineStylePicker(
                    selectedStyle: $selectedStyle,
                    selectedColor: $selectedColor,
                    previewText: underline.text,
                    onConfirm: {
                        updateStyle()
                        showingStylePicker = false
                    },
                    onCancel: {
                        showingStylePicker = false
                    }
                )
            )
            .onAppear {
                note = underline.note
                selectedStyle = underline.style
                selectedColor = underline.color
            }
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
    
    private func saveNote() {
        underlineManager.updateUnderlineNote(underline, note: note)
        dismiss()
    }
    
    private func updateStyle() {
        underlineManager.updateUnderlineStyle(underline, style: selectedStyle)
        underlineManager.updateUnderlineColor(underline, color: selectedColor)
    }
}

struct UnderlineListInReader: View {
    let bookId: String
    let chapterId: String
    let onSelectUnderline: (UnderlineManager.Underline) -> Void
    @StateObject private var underlineManager = UnderlineManager.shared
    
    var chapterUnderlines: [UnderlineManager.Underline] {
        underlineManager.getUnderlines(for: bookId, chapterId: chapterId)
    }
    
    var body: some View {
        if chapterUnderlines.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "underline")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("本章暂无下划线")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(chapterUnderlines) { underline in
                Button(action: {
                    onSelectUnderline(underline)
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(underline.text)
                            .font(.body)
                            .underline(
                                style: getTextDecorationStyle(underline.style),
                                color: Color(hex: underline.color.hexColor) ?? .blue
                            )
                            .lineLimit(3)
                        
                        if !underline.note.isEmpty {
                            Text(underline.note)
                                .font(.caption)
                                .foregroundColor(.orange)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        underlineManager.removeUnderline(underline)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
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
}

extension Text.DecorationStyle {
    static func style(_ configuration: Configuration) -> Text.DecorationStyle {
        return .init(pattern: configuration.pattern)
    }
    
    struct Configuration {
        var pattern: Pattern
        
        enum Pattern {
            case dot
            case dash
            case wave
        }
    }
}
