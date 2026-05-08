import SwiftUI

struct AnnotationEditView: View {
    @Environment(\.dismiss) var dismiss
    
    let bookId: String
    let chapterId: String
    let chapterIndex: Int
    let chapterTitle: String
    let bookName: String
    let selectedText: String
    let selectedRange: NSRange
    let existingAnnotation: AnnotationService.Annotation?
    let onSave: (AnnotationService.Annotation) -> Void
    
    @StateObject private var styleManager = AnnotationStyleManager.shared
    @State private var noteContent: String = ""
    @State private var selectedStyle: AnnotationService.Annotation.AnnotationStyle = .highlight
    @State private var selectedColorHex: String = "#FFF59D"
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text(selectedText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                } header: {
                    Text("选中的内容")
                }
                
                Section {
                    TextField("笔记内容", text: $noteContent, axis: .vertical)
                        .lineLimit(5...10)
                } header: {
                    Text("笔记")
                }
                
                Section {
                    HStack {
                        Text("批注样式")
                        Spacer()
                        Picker("", selection: $selectedStyle) {
                            ForEach(AnnotationService.Annotation.AnnotationStyle.allCases, id: \.self) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(.menu)
                        .foregroundColor(.blue)
                    }
                } header: {
                    Text("批注样式")
                }
                
                Section {
                    HStack {
                        Text("颜色")
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach(AnnotationService.Annotation.AnnotationColor.defaultColors, id: \.id) { color in
                                Button(action: {
                                    selectedColorHex = color.hex
                                }) {
                                    Circle()
                                        .fill(Color(hex: color.hex) ?? .yellow)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColorHex == color.hex ? Color(hex: color.hex) ?? .blue : Color.clear, lineWidth: 2)
                                        )
                                }
                            }
                        }
                    }
                } header: {
                    Text("颜色")
                }
                
                Section {
                    if !tags.isEmpty {
                        ForEach(tags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                Spacer()
                                Button(action: { tags.removeAll { $0 == tag } }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    HStack {
                        TextField("添加标签", text: $newTag)
                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .disabled(newTag.isEmpty)
                    }
                } header: {
                    Text("标签")
                }
                
                if existingAnnotation != nil {
                    Section {
                        Button(role: .destructive, action: deleteAnnotation) {
                            HStack {
                                Spacer()
                                Text("删除批注")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(existingAnnotation != nil ? "编辑批注" : "添加批注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveAnnotation()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let annotation = existingAnnotation {
                    noteContent = annotation.note
                    selectedStyle = annotation.style
                    selectedColorHex = annotation.colorHex
                    tags = annotation.tags
                } else {
                    selectedStyle = styleManager.currentStyle
                    selectedColorHex = styleManager.currentColor.hex
                }
            }
        }
    }
    
    private func addTag() {
        guard !newTag.isEmpty else { return }
        tags.append(newTag)
        newTag = ""
    }
    
    private func saveAnnotation() {
        let annotation: AnnotationService.Annotation
        let startOffset = existingAnnotation?.startOffset ?? selectedRange.location
        let endOffset = existingAnnotation?.endOffset ?? (selectedRange.location + selectedRange.length)
        
        if let existing = existingAnnotation {
            annotation = AnnotationService.Annotation(
                id: existing.id,
                bookId: bookId,
                chapterId: chapterId,
                chapterIndex: chapterIndex,
                chapterTitle: chapterTitle,
                bookName: bookName,
                startOffset: startOffset,
                endOffset: endOffset,
                text: selectedText,
                style: selectedStyle,
                note: noteContent,
                tags: tags,
                colorHex: selectedColorHex
            )
        } else {
            annotation = AnnotationService.Annotation(
                bookId: bookId,
                chapterId: chapterId,
                chapterIndex: chapterIndex,
                chapterTitle: chapterTitle,
                bookName: bookName,
                startOffset: startOffset,
                endOffset: endOffset,
                text: selectedText,
                style: selectedStyle,
                note: noteContent,
                tags: tags,
                colorHex: selectedColorHex
            )
        }
        
        onSave(annotation)
    }
    
    private func deleteAnnotation() {
        if let annotation = existingAnnotation {
            AnnotationService.shared.removeAnnotation(annotation)
        }
        dismiss()
    }
}
