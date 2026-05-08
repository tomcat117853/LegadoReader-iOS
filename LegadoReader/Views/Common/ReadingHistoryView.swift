import SwiftUI

struct ReadingRecord: Identifiable, Codable {
    var id: String
    var bookId: String
    var bookName: String
    var bookCover: String?
    var readDate: Date
    var duration: TimeInterval
    var lastChapter: String?
    var progress: Double
    
    init(book: Book, duration: TimeInterval = 0) {
        self.id = UUID().uuidString
        self.bookId = book.id
        self.bookName = book.name
        self.bookCover = book.cover
        self.readDate = Date()
        self.duration = duration
        self.lastChapter = book.lastReadChapter
        self.progress = book.progress
    }
}

class ReadingHistoryManager: BaseService, ObservableObject {
    static let shared = ReadingHistoryManager()
    
    @Published var records: [ReadingRecord] = []
    
    private let recordsKey = "ReadingRecords"
    private let maxRecords = 100
    
    func loadRecords() {
        records = loadCodable([ReadingRecord].self, key: recordsKey) ?? []
    }
    
    func saveRecord(_ record: ReadingRecord) {
        records.insert(record, at: 0)
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }
        saveCodable(records, key: recordsKey)
    }
    
    func deleteRecord(_ id: String) {
        if let index = records.firstIndex(where: { $0.id == id }) {
            records.remove(at: index)
            saveCodable(records, key: recordsKey)
        }
    }
    
    func clearAllRecords() {
        records.removeAll()
        saveCodable(records, key: recordsKey)
    }
    
    func getTodayReadingMinutes() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayRecords = records.filter { calendar.startOfDay(for: $0.readDate) >= today }
        let totalSeconds = todayRecords.reduce(0) { $0 + $1.duration }
        return Int(totalSeconds / 60)
    }
    
    func getTotalReadingMinutes() -> Int {
        let totalSeconds = records.reduce(0) { $0 + $1.duration }
        return Int(totalSeconds / 60)
    }
    
    func getReadingStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()
        
        while true {
            let startOfDay = calendar.startOfDay(for: currentDate)
            let hasRecord = records.contains { calendar.startOfDay(for: $0.readDate) == startOfDay }
            
            if hasRecord {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }
        
        return streak
    }
}

struct ReadingHistoryView: View {
    @StateObject private var historyManager = ReadingHistoryManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: statisticsHeader) {
                    ForEach(historyManager.records) { record in
                        ReadingRecordRow(record: record)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            historyManager.deleteRecord(historyManager.records[index].id)
                        }
                    }
                    
                    if historyManager.records.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "book.open")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("暂无阅读记录")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("开始阅读后，记录将显示在这里")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 200)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("阅读记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            historyManager.clearAllRecords()
                        } label: {
                            Label("清空记录", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                historyManager.loadRecords()
            }
        }
    }
    
    private var statisticsHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                StatCard(value: "\(historyManager.getTodayReadingMinutes())", label: "今日阅读(分钟)")
                StatCard(value: "\(historyManager.getTotalReadingMinutes())", label: "累计阅读(分钟)")
                StatCard(value: "\(historyManager.getReadingStreak())", label: "连续天数")
            }
        }
        .padding(.vertical, 8)
    }
}

struct StatCard: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ReadingRecordRow: View {
    let record: ReadingRecord
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 70)
                
                if let cover = record.bookCover, let url = URL(string: cover) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 50, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "book.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.bookName)
                    .font(.headline)
                    .lineLimit(1)
                
                if let chapter = record.lastChapter {
                    Text(chapter)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    Text(formatDate(record.readDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if record.duration > 0 {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text("\(Int(record.duration / 60))分钟")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            if record.progress > 0 {
                Text("\(Int(record.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
