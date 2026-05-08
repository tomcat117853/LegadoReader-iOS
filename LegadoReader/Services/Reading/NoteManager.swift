import Foundation

class NoteManager: BaseDataManager<NoteManager.Note> {
    static let shared = NoteManager()
    
    @Published var bookNotes: [String: [Note]] = [:]
    
    private init() {
        super.init(dataKey: "NoteManager_notes")
        updateBookNotes()
    }
    
    override func saveData() {
        super.saveData()
        updateBookNotes()
    }
    
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
    
    private func updateBookNotes() {
        bookNotes = Dictionary(grouping: items, by: { $0.bookId })
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
        
        items.insert(note, at: 0)
        saveData()
        
        return note
    }
    
    func updateNote(_ note: Note) {
        if let index = items.firstIndex(where: { $0.id == note.id }) {
            items[index] = note
            items[index].modifiedTime = Date()
            saveData()
        }
    }
    
    func deleteNote(_ note: Note) {
        removeItem(note.id)
    }
    
    func deleteNote(id: String) {
        removeItem(id)
    }
    
    func getNotes(for bookId: String) -> [Note] {
        return items.filter { $0.bookId == bookId }
    }
    
    func getNotes(for bookId: String, chapterIndex: Int) -> [Note] {
        return items.filter { $0.bookId == bookId && $0.chapterIndex == chapterIndex }
    }
    
    func getNote(id: String) -> Note? {
        return getItem(id)
    }
    
    func searchNotes(keyword: String) -> [Note] {
        guard !keyword.isEmpty else { return items }
        
        return items.filter { note in
            note.content.contains(keyword) ||
            note.bookName.contains(keyword) ||
            note.chapterTitle.contains(keyword) ||
            note.tags.contains(keyword)
        }
    }
    
    func addTag(to noteId: String, tag: String) {
        if let index = items.firstIndex(where: { $0.id == noteId }) {
            if !items[index].tags.contains(tag) {
                items[index].tags.append(tag)
                saveData()
            }
        }
    }
    
    func removeTag(from noteId: String, tag: String) {
        if let index = items.firstIndex(where: { $0.id == noteId }) {
            items[index].tags.removeAll { $0 == tag }
            saveData()
        }
    }
    
    func getAllTags() -> [String] {
        let allTags = items.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }
    
    func getNotesWithTag(_ tag: String) -> [Note] {
        return items.filter { $0.tags.contains(tag) }
    }
    
    func exportNotes() -> Data? {
        return exportData()
    }
    
    func importNotes(from data: Data) -> Bool {
        guard let importedNotes = decodeJSON([Note].self, from: data) else {
            return false
        }
        
        for note in importedNotes {
            if !items.contains(where: { $0.id == note.id }) {
                items.append(note)
            }
        }
        
        items.sort { $0.createdTime > $1.createdTime }
        saveData()
        
        return true
    }
    
    func getNotesStatistics() -> NotesStatistics {
        let totalNotes = items.count
        let booksWithNotes = Set(items.map { $0.bookId }).count
        let notesWithTags = items.filter { !$0.tags.isEmpty }.count
        let todayNotes = items.filter {
            Calendar.current.isDate($0.createdTime, inSameDayAs: Date())
        }.count
        
        return NotesStatistics(
            totalNotes: totalNotes,
            booksWithNotes: booksWithNotes,
            notesWithTags: notesWithTags,
            todayNotes: todayNotes
        )
    }
    
    struct NotesStatistics {
        let totalNotes: Int
        let booksWithNotes: Int
        let notesWithTags: Int
        let todayNotes: Int
    }
}
