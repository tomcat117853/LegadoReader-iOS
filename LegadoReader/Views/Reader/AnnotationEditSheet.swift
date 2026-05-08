import SwiftUI

struct AnnotationEditSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let bookId: String
    let chapterId: String
    let chapterIndex: Int
    let chapterTitle: String
    let bookName: String
    let selectedText: String
    let startOffset: Int
    let endOffset: Int
    
    @State private var noteContent: String = ""
    @State private var selectedStyle: AnnotationService.Annotation.AnnotationStyle = .highlight
    @State private var selectedColorHex: String = "#FFF59D"
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var isNewAnnotation: Bool = true
    @State private var annotationId: String = ""
    
    init(
        bookId: String,
        chapterId: String,
        chapterIndex: Int,
        chapterTitle: String,
        bookName: String,
        selectedText: String,
        startOffset: Int,
        endOffset: Int,
        annotation: AnnotationService.Annotation? = nil
    ) {
        self.bookId = bookId
        self.chapterId = chapterId
        self.chapterIndex = chapterIndex
        self.chapterTitle = chapterTitle
        self.bookName = bookName
        self.selectedText = selectedText
        self.startOffset = startOffset
        self.endOffset = endOffset
        
        if let annotation = annotation {
            self._noteContent = State(initialValue: annotation.note)
            self._selectedStyle = State(initialValue: annotation.style)
            self._selectedColorHex = State(initialValue: annotation.colorHex)
            self._tags = State(initialValue: annotation.tags)
            self._isNewAnnotation = State(initialValue: false)
            self._annotationId = State(initialValue: annotation.id)
        }
    }
    
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
                            ForEach(AnnotationService.AnnotationColor.defaultColors, id: \.id) { color in
                                Button(action: {
                                    selectedColorHex = color.hex
                                }) {
                                    Circle()
                                        .fill(Color(hex: color.hex) ?? .yellow)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColorHex == color.hex ? Color.blue : Color.clear, lineWidth: 2)
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
                
                if !isNewAnnotation {
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
            .navigationTitle(isNewAnnotation ? "添加批注" : "编辑批注")
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
        }
    }
    
    private func addTag() {
        guard !newTag.isEmpty else { return }
        tags.append(newTag)
        newTag = ""
    }
    
    private func saveAnnotation() {
        let annotationService = AnnotationService.shared
        
        if isNewAnnotation {
            let annotation = AnnotationService.Annotation(
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
            annotationService.addAnnotation(annotation)
        } else {
            var updatedAnnotation = AnnotationService.Annotation(
                id: annotationId,
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
            annotationService.updateAnnotation(updatedAnnotation)
        }
        
        dismiss()
    }
    
    private func deleteAnnotation() {
        let annotationService = AnnotationService.shared
        let annotation = AnnotationService.Annotation(
            id: annotationId,
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
        annotationService.removeAnnotation(annotation)
        dismiss()
    }
}