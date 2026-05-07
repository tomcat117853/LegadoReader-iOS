import Foundation

class NoteManager: ObservableObject {
    static let shared = NoteManager()
    
    @Published var notes: [Note] = []
    @Published var bookNotes: [String: [Note]] = [:]
    
    struct Note: Identifiable, Codable {
        let id: String
        let bookId: String
        let bookName: String
        let chapterTitle: String
        let chapterIndex: Int
        var content: String
        var highlightText: String?
        var highlightRange: HighlightRange?
        let createdTime: Date
        var modifiedTime: Date
        var tags: [String]
        var color: NoteColor
        
        struct HighlightRange: Codable {
            let start: Int
            let end: Int
        }
        
        enum NoteColor: String, Codable, CaseIterable {
            case yellow = "黄色"
            case green = "绿色"
            case blue = "蓝色"
            case pink = "粉色"
            case orange = "橙色"
            
            var hex: String {
                switch self {
                case .yellow: return "#FFF59D"
                case .green: return "#A5D6A7"
                case .blue: return "#90CAF9"
                case .pink: return "#F48FB1"
                case .orange: return "#FFCC80"
                }
            }
        }
    }
    
    private let defaults = UserDefaults.standard
    private let notesKey = "NoteManager_notes"
    
    private init() {
        loadNotes()
    }
    
    private func loadNotes() {
        if let data = defaults.data(forKey: notesKey),
           let savedNotes = try? JSONDecoder().decode([Note].self, from: data) {
            notes = savedNotes
            updateBookNotes()
        }
    }
    
    private func saveNotes() {
        if let data = try? JSONEncoder().encode(notes) {
            defaults.set(data, forKey: notesKey)
        }
    }
    
    private func updateBookNotes() {
        bookNotes = Dictionary(grouping: notes, by: { $0.bookId })
    }
    
    func createNote(bookId: String, bookName: String, chapterTitle: String, chapterIndex: Int, content: String, highlightText: String? = nil, highlightRange: Note.HighlightRange? = nil, color: Note.NoteColor = .yellow) -> Note {
        let note = Note(
            id: UUID().uuidString,
            bookId: bookId,
            bookName: bookName,
            chapterTitle: chapterTitle,
            chapterIndex: chapterIndex,
            content: content,
            highlightText: highlightText,
            highlightRange: highlightRange,
            createdTime: Date(),
            modifiedTime: Date(),
            tags: [],
            color: color
        )
        
        notes.insert(note, at: 0)
        updateBookNotes()
        saveNotes()
        
        return note
    }
    
    func updateNote(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
            notes[index].modifiedTime = Date()
            updateBookNotes()
            saveNotes()
        }
    }
    
    func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        updateBookNotes()
        saveNotes()
    }
    
    func deleteNote(id: String) {
        notes.removeAll { $0.id == id }
        updateBookNotes()
        saveNotes()
    }
    
    func getNotes(for bookId: String) -> [Note] {
        return bookNotes[bookId] ?? []
    }
    
    func getNotes(for bookId: String, chapterIndex: Int) -> [Note] {
        return notes.filter { $0.bookId == bookId && $0.chapterIndex == chapterIndex }
    }
    
    func addTag(to noteId: String, tag: String) {
        if let index = notes.firstIndex(where: { $0.id == noteId }) {
            if !notes[index].tags.contains(tag) {
                notes[index].tags.append(tag)
                notes[index].modifiedTime = Date()
                updateBookNotes()
                saveNotes()
            }
        }
    }
    
    func removeTag(from noteId: String, tag: String) {
        if let index = notes.firstIndex(where: { $0.id == noteId }) {
            notes[index].tags.removeAll { $0 == tag }
            notes[index].modifiedTime = Date()
            updateBookNotes()
            saveNotes()
        }
    }
    
    func searchNotes(keyword: String) -> [Note] {
        return notes.filter {
            $0.content.localizedCaseInsensitiveContains(keyword) ||
            ($0.highlightText?.localizedCaseInsensitiveContains(keyword) ?? false) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(keyword) }
        }
    }
    
    func getAllTags() -> [String] {
        var allTags = Set<String>()
        for note in notes {
            allTags.formUnion(note.tags)
        }
        return Array(allTags).sorted()
    }
    
    func exportNotes() -> String {
        var export = "# 阅读笔记导出\n\n"
        export += "导出时间: \(Date())\n\n"
        
        let groupedNotes = Dictionary(grouping: notes, by: { $0.bookName })
        
        for (bookName, bookNotes) in groupedNotes {
            export += "## \(bookName)\n\n"
            
            for note in bookNotes.sorted(by: { $0.createdTime > $1.createdTime }) {
                export += "### \(note.chapterTitle)\n"
                export += "时间: \(note.createdTime)\n"
                
                if let highlight = note.highlightText {
                    export += "高亮: \"\(highlight)\"\n"
                }
                
                export += "\(note.content)\n\n"
                
                if !note.tags.isEmpty {
                    export += "标签: \(note.tags.joined(separator: ", "))\n"
                }
                
                export += "---\n\n"
            }
        }
        
        return export
    }
}

struct NotesView: View {
    let bookId: String
    @StateObject private var noteManager = NoteManager.shared
    @State private var searchText = ""
    @State private var selectedNote: NoteManager.Note?
    @State private var showingAddNote = false
    @Environment(\.dismiss) var dismiss
    
    var filteredNotes: [NoteManager.Note] {
        let bookNotes = noteManager.getNotes(for: bookId)
        if searchText.isEmpty {
            return bookNotes
        }
        return bookNotes.filter {
            $0.content.localizedCaseInsensitiveContains(searchText) ||
            ($0.highlightText?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if filteredNotes.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "note.text")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("暂无笔记")
                                .foregroundColor(.gray)
                            Text("长按选择文字即可添加笔记")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else {
                    ForEach(filteredNotes) { note in
                        NoteRow(note: note)
                            .onTapGesture {
                                selectedNote = note
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    noteManager.deleteNote(note)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("阅读笔记")
            .searchable(text: $searchText, prompt: "搜索笔记...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddNote = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $selectedNote) { note in
                NoteEditView(note: note, isNew: false)
            }
            .sheet(isPresented: $showingAddNote) {
                NoteEditView(note: nil, isNew: true)
            }
        }
    }
}

struct NoteRow: View {
    let note: NoteManager.Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let highlight = note.highlightText {
                    Text("\"\(highlight)\"")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text(note.createdTime, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(note.content)
                .font(.body)
                .lineLimit(3)
            
            HStack {
                Text(note.chapterTitle)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .lineLimit(1)
                
                Spacer()
                
                if !note.tags.isEmpty {
                    ForEach(note.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct NoteEditView: View {
    let note: NoteManager.Note?
    let isNew: Bool
    @StateObject private var noteManager = NoteManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var content: String = ""
    @State private var selectedColor: NoteManager.Note.NoteColor = .yellow
    @State private var tagInput: String = ""
    @State private var tags: [String] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section("笔记内容") {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                }
                
                Section("高亮颜色") {
                    HStack(spacing: 12) {
                        ForEach(NoteManager.Note.NoteColor.allCases, id: \.self) { color in
                            Button(action: {
                                selectedColor = color
                            }) {
                                Circle()
                                    .fill(Color(hex: color.hex))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor == color ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("标签") {
                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                Button(action: {
                                    tags.removeAll { $0 == tag }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                        }
                        
                        HStack {
                            TextField("添加标签", text: $tagInput)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                            
                            Button(action: addTag) {
                                Image(systemName: "plus.circle.fill")
                            }
                            .disabled(tagInput.isEmpty)
                        }
                    }
                }
                
                Section {
                    Button(action: shareNote) {
                        Label("分享笔记", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle(isNew ? "添加笔记" : "编辑笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveNote()
                        dismiss()
                    }
                    .disabled(content.isEmpty)
                }
            }
            .onAppear {
                if let note = note {
                    content = note.content
                    selectedColor = note.color
                    tags = note.tags
                }
            }
        }
    }
    
    private func addTag() {
        if !tagInput.isEmpty && !tags.contains(tagInput) {
            tags.append(tagInput)
            tagInput = ""
        }
    }
    
    private func saveNote() {
        if let existingNote = note {
            var updatedNote = existingNote
            updatedNote.content = content
            updatedNote.color = selectedColor
            updatedNote.tags = tags
            noteManager.updateNote(updatedNote)
        } else {
            let _ = noteManager.createNote(
                bookId: "",
                bookName: "",
                chapterTitle: "",
                chapterIndex: 0,
                content: content,
                color: selectedColor
            )
        }
    }
    
    private func shareNote() {
        let shareText = """
        \(note?.highlightText ?? "")
        
        笔记: \(content)
        
        来自: \(note?.bookName ?? "") - \(note?.chapterTitle ?? "")
        """
        
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        
        for (index, subview) in subviews.enumerated() {
            let point = CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y)
            subview.place(at: point, proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        
        let maxX = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxX && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxWidth = max(maxWidth, currentX)
        }
        
        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}
