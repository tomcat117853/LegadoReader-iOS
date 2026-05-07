import Foundation

class RecommendationManager: ObservableObject {
    static let shared = RecommendationManager()
    
    @Published var recommendations: [Book] = []
    @Published var personalizedBooks: [Book] = []
    @Published var hotBooks: [Book] = []
    @Published var newBooks: [Book] = []
    @Published var isLoading = false
    
    private let defaults = UserDefaults.standard
    private let readHistoryKey = "RecommendationManager_readHistory"
    private let preferencesKey = "RecommendationManager_preferences"
    
    struct ReadingPreference: Codable {
        var favoriteCategories: [String]
        var favoriteAuthors: [String]
        var readBookIds: [String]
    }
    
    private init() {
        loadPreferences()
    }
    
    private func loadPreferences() {
        if let data = defaults.data(forKey: preferencesKey),
           let prefs = try? JSONDecoder().decode(ReadingPreference.self, from: data) {
            updateRecommendations(basedOn: prefs)
        }
    }
    
    func savePreference() {
        let prefs = ReadingPreference(
            favoriteCategories: favoriteCategories,
            favoriteAuthors: favoriteAuthors,
            readBookIds: readBookIds
        )
        
        if let data = try? JSONEncoder().encode(prefs) {
            defaults.set(data, forKey: preferencesKey)
        }
    }
    
    private var favoriteCategories: [String] = []
    private var favoriteAuthors: [String] = []
    private var readBookIds: [String] = []
    
    func addToReadHistory(_ book: Book) {
        if !readBookIds.contains(book.id) {
            readBookIds.append(book.id)
            savePreference()
        }
    }
    
    func updateRecommendations(basedOn prefs: ReadingPreference) {
        favoriteCategories = prefs.favoriteCategories
        favoriteAuthors = prefs.favoriteAuthors
        readBookIds = prefs.readBookIds
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
            hotBooks = Array(allBooks.sorted { $0.readCount > $1.readCount }.prefix(20))
            newBooks = Array(allBooks.sorted { $0.updatedTime > $1.updatedTime }.prefix(20))
            isLoading = false
        }
    }
    
    private func recommendPersonalized(from books: [Book]) -> [Book] {
        guard !favoriteCategories.isEmpty || !favoriteAuthors.isEmpty else {
            return Array(books.shuffled().prefix(10))
        }
        
        var scoredBooks: [(book: Book, score: Int)] = []
        
        for book in books {
            var score = 0
            
            if favoriteCategories.contains(where: { book.name.contains($0) || book.author.contains($0) }) {
                score += 10
            }
            
            if favoriteAuthors.contains(where: { book.author.contains($0) }) {
                score += 5
            }
            
            if !readBookIds.contains(book.id) {
                score += 3
            }
            
            if score > 0 {
                scoredBooks.append((book: book, score: score))
            }
        }
        
        return scoredBooks
            .sorted { $0.score > $1.score }
            .prefix(10)
            .map { $0.book }
    }
    
    func getSimilarBooks(to book: Book) -> [Book] {
        return recommendations.filter {
            $0.id != book.id &&
            (($0.author == book.author) || hasSimilarCategory($0, book))
        }
    }
    
    private func hasSimilarCategory(_ book1: Book, _ book2: Book) -> Bool {
        let keywords1 = Set(book1.name.lowercased().components(separatedBy: ""))
        let keywords2 = Set(book2.name.lowercased().components(separatedBy: ""))
        let intersection = keywords1.intersection(keywords2)
        return intersection.count > 5
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
