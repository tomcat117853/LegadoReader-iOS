import Foundation

class RecommendationManager: ObservableObject {
    static let shared = RecommendationManager()
    
    @Published var recommendations: [Book] = []
    @Published var personalizedBooks: [Book] = []
    @Published var hotBooks: [Book] = []
    @Published var newBooks: [Book] = []
    @Published var similarBooks: [Book] = []
    @Published var readingHistory: [Book] = []
    @Published var isLoading = false
    
    private let defaults = UserDefaults.standard
    private let readHistoryKey = "RecommendationManager_readHistory"
    private let preferencesKey = "RecommendationManager_preferences"
    private let historyBooksKey = "RecommendationManager_historyBooks"
    
    struct ReadingPreference: Codable {
        var favoriteCategories: [String]
        var favoriteAuthors: [String]
        var favoriteTags: [String]
        var readBookIds: [String]
        var totalReadTime: TimeInterval
        var lastReadDate: Date?
        var preferredChapterLength: Int
    }
    
    struct BookFeature: Hashable {
        let words: Set<String>
        let length: Int
        let author: String
    }
    
    private var favoriteCategories: [String] = []
    private var favoriteAuthors: [String] = []
    private var favoriteTags: [String] = []
    private var readBookIds: [String] = []
    private var totalReadTime: TimeInterval = 0
    private var lastReadDate: Date?
    private var preferredChapterLength: Int = 0
    
    private init() {
        loadPreferences()
        loadHistoryBooks()
    }
    
    private func loadPreferences() {
        if let data = defaults.data(forKey: preferencesKey),
           let prefs = try? JSONDecoder().decode(ReadingPreference.self, from: data) {
            favoriteCategories = prefs.favoriteCategories
            favoriteAuthors = prefs.favoriteAuthors
            favoriteTags = prefs.favoriteTags
            readBookIds = prefs.readBookIds
            totalReadTime = prefs.totalReadTime
            lastReadDate = prefs.lastReadDate
            preferredChapterLength = prefs.preferredChapterLength
        }
    }
    
    func savePreference() {
        let prefs = ReadingPreference(
            favoriteCategories: favoriteCategories,
            favoriteAuthors: favoriteAuthors,
            favoriteTags: favoriteTags,
            readBookIds: readBookIds,
            totalReadTime: totalReadTime,
            lastReadDate: lastReadDate,
            preferredChapterLength: preferredChapterLength
        )
        
        if let data = try? JSONEncoder().encode(prefs) {
            defaults.set(data, forKey: preferencesKey)
        }
    }
    
    private func loadHistoryBooks() {
        if let data = defaults.data(forKey: historyBooksKey),
           let books = try? JSONDecoder().decode([Book].self, from: data) {
            readingHistory = books
        }
    }
    
    private func saveHistoryBooks() {
        if let data = try? JSONEncoder().encode(readingHistory) {
            defaults.set(data, forKey: historyBooksKey)
        }
    }
    
    func addToReadHistory(_ book: Book, readingTime: TimeInterval = 0) {
        if !readBookIds.contains(book.id) {
            readBookIds.append(book.id)
            readingHistory.insert(book, at: 0)
            if readingHistory.count > 50 {
                readingHistory.removeLast()
            }
            saveHistoryBooks()
            
            totalReadTime += readingTime
            lastReadDate = Date()
            
            if let content = book.intro, !content.isEmpty {
                extractKeywords(from: content, to: &favoriteCategories)
            }
            
            if !favoriteAuthors.contains(book.author) {
                favoriteAuthors.append(book.author)
            }
            
            savePreference()
        }
    }
    
    private func extractKeywords(from text: String, to keywords: inout [String]) {
        let patterns = ["都市", "玄幻", "修真", "科幻", "言情", "穿越", "重生", "系统", "游戏", "悬疑", "恐怖", "武侠", "仙侠", "校园", "职场"]
        
        for pattern in patterns {
            if text.contains(pattern) && !keywords.contains(pattern) {
                keywords.append(pattern)
            }
        }
    }
    
    func updateRecommendations(basedOn prefs: ReadingPreference) {
        favoriteCategories = prefs.favoriteCategories
        favoriteAuthors = prefs.favoriteAuthors
        favoriteTags = prefs.favoriteTags
        readBookIds = prefs.readBookIds
        totalReadTime = prefs.totalReadTime
        lastReadDate = prefs.lastReadDate
        preferredChapterLength = prefs.preferredChapterLength
    }
    
    func fetchRecommendations() async {
        await MainActor.run {
            isLoading = true
        }
        
        let sources = DatabaseManager.shared.getAllBookSources()
        var allBooks: [Book] = []
        
        for source in sources where source.isEnabled {
            let discoverBooks = await BookSourceParser.shared.parseDiscover(source: source)
            allBooks.append(contentsOf: discoverBooks)
        }
        
        await MainActor.run {
            recommendations = allBooks.shuffled().prefix(20).map { $0 }
            personalizedBooks = recommendPersonalized(from: allBooks)
            hotBooks = Array(allBooks.sorted { ($0.intro?.count ?? 0) > ($1.intro?.count ?? 0) }.prefix(20))
            newBooks = Array(allBooks.sorted { ($0.addedTime) > ($1.addedTime) }.prefix(20))
            isLoading = false
        }
    }
    
    private func recommendPersonalized(from books: [Book]) -> [Book] {
        let unreadBooks = books.filter { !readBookIds.contains($0.id) }
        
        if unreadBooks.isEmpty {
            return Array(books.shuffled().prefix(10))
        }
        
        var scoredBooks: [(book: Book, score: Double)] = []
        
        for book in unreadBooks {
            let score = calculateBookScore(book: book, from: unreadBooks)
            scoredBooks.append((book: book, score: score))
        }
        
        let topBooks = scoredBooks
            .sorted { $0.score > $1.score }
            .prefix(15)
            .map { $0.book }
        
        return diversifyRecommendations(topBooks)
    }
    
    private func calculateBookScore(book: Book, from allBooks: [Book]) -> Double {
        var score: Double = 0
        
        for category in favoriteCategories {
            if book.name.contains(category) {
                score += 15
            }
            if book.intro?.contains(category) == true {
                score += 8
            }
        }
        
        for author in favoriteAuthors {
            if book.author.contains(author) {
                score += 10
            }
        }
        
        for tag in favoriteTags {
            if book.name.contains(tag) || book.intro?.contains(tag) == true {
                score += 5
            }
        }
        
        let feature1 = extractBookFeature(book)
        for historyBook in readingHistory.prefix(10) {
            let feature2 = extractBookFeature(historyBook)
            let similarity = calculateSimilarity(feature1, feature2)
            score += similarity * 12
        }
        
        if let lastRead = lastReadDate {
            let daysSinceLastRead = Calendar.current.dateComponents([.day], from: lastRead, to: Date()).day ?? 0
            if daysSinceLastRead < 7 {
                score += 5
            }
        }
        
        let authorPopularity = allBooks.filter { $0.author == book.author }.count
        score += min(Double(authorPopularity) * 0.5, 5)
        
        return score
    }
    
    private func extractBookFeature(_ book: Book) -> BookFeature {
        let words = Set(book.name.lowercased() + (book.intro ?? "").lowercased())
        return BookFeature(
            words: words,
            length: (book.intro?.count ?? 0),
            author: book.author
        )
    }
    
    private func calculateSimilarity(_ f1: BookFeature, _ f2: BookFeature) -> Double {
        if f1.author == f2.author {
            return 1.0
        }
        
        let wordIntersection = f1.words.intersection(f2.words)
        let wordUnion = f1.words.union(f2.words)
        
        guard !wordUnion.isEmpty else { return 0 }
        
        let jaccard = Double(wordIntersection.count) / Double(wordUnion.count)
        
        let lengthDiff = abs(f1.length - f2.length)
        let lengthSimilarity = max(0, 1.0 - Double(lengthDiff) / 1000.0)
        
        return (jaccard * 0.6 + lengthSimilarity * 0.4)
    }
    
    private func diversifyRecommendations(_ books: [Book]) -> [Book] {
        var result: [Book] = []
        var usedAuthors: [String: Int] = [:]
        var usedCategories: Set<String> = []
        
        for book in books {
            let authorCount = usedAuthors[book.author] ?? 0
            if authorCount < 2 {
                result.append(book)
                usedAuthors[book.author] = authorCount + 1
                
                for category in favoriteCategories {
                    if book.name.contains(category) {
                        usedCategories.insert(category)
                        break
                    }
                }
            }
            
            if result.count >= 10 {
                break
            }
        }
        
        return result
    }
    
    func getSimilarBooks(to book: Book, from allBooks: [Book]) -> [Book] {
        let targetFeature = extractBookFeature(book)
        
        var similarBooks: [(Book, Double)] = []
        
        for candidate in allBooks where candidate.id != book.id {
            let candidateFeature = extractBookFeature(candidate)
            let similarity = calculateSimilarity(targetFeature, candidateFeature)
            if similarity > 0.3 {
                similarBooks.append((candidate, similarity))
            }
        }
        
        return similarBooks
            .sorted { $0.1 > $1.1 }
            .prefix(8)
            .map { $0.0 }
    }
    
    func getRecommendedAuthors() -> [String] {
        var authorScores: [String: Int] = [:]
        
        for book in readingHistory {
            authorScores[book.author, default: 0] += 1
        }
        
        return authorScores
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }
    
    func getRecommendedCategories() -> [String] {
        return favoriteCategories.prefix(5).map { $0 }
    }
}

struct RecommendationView: View {
    @StateObject private var recommendationManager = RecommendationManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("推荐类型", selection: $selectedTab) {
                    Text("推荐").tag(0)
                    Text("热门").tag(1)
                    Text("新作").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if recommendationManager.isLoading {
                    Spacer()
                    ProgressView("加载中...")
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(currentBooks) { book in
                                RecommendationBookCard(book: book)
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await recommendationManager.fetchRecommendations()
                    }
                }
            }
            .navigationTitle("为你推荐")
            .onAppear {
                Task {
                    await recommendationManager.fetchRecommendations()
                }
            }
        }
    }
    
    private var currentBooks: [Book] {
        switch selectedTab {
        case 0: return recommendationManager.personalizedBooks
        case 1: return recommendationManager.hotBooks
        case 2: return recommendationManager.newBooks
        default: return recommendationManager.recommendations
        }
    }
}

struct RecommendationBookCard: View {
    let book: Book
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: book.coverUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
            }
            .frame(width: 80, height: 110)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(book.name)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(book.intro ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    if book.readCount > 0 {
                        Label("\(formatCount(book.readCount))", systemImage: "eye")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(book.sourceName ?? "")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatCount(_ count: Int) -> String {
        if count > 10000 {
            return String(format: "%.1f万", Double(count) / 10000)
        } else if count > 1000 {
            return String(format: "%.1f千", Double(count) / 1000)
        }
        return "\(count)"
    }
}
