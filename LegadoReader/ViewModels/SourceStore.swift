import Foundation
import Combine

class SourceStore: ObservableObject {
    @Published var bookSources: [BookSource] = []
    @Published var rssSources: [RSSSource] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        loadSources()
    }
    
    // MARK: - Book Source Management
    
    func loadSources() {
        bookSources = DatabaseManager.shared.getAllBookSources()
    }
    
    func addBookSource(_ source: BookSource) {
        if DatabaseManager.shared.saveBookSource(source) {
            loadSources()
        }
    }
    
    func removeBookSource(_ source: BookSource) {
        // 实现删除逻辑
    }
    
    func toggleSourceEnabled(_ source: BookSource) {
        var updatedSource = source
        updatedSource.isEnabled.toggle()
        addBookSource(updatedSource)
    }
    
    func updateSourceWeight(_ source: BookSource, weight: Int) {
        var updatedSource = source
        updatedSource.weight = weight
        addBookSource(updatedSource)
    }
    
    // MARK: - Import/Export
    
    func importBookSources(from jsonString: String) -> Int {
        do {
            let sources = try BookSourceParser.shared.importBookSource(from: jsonString)
            for source in sources {
                addBookSource(source)
            }
            return sources.count
        } catch {
            errorMessage = "导入失败: \(error.localizedDescription)"
            return 0
        }
    }
    
    func exportBookSources() -> String? {
        // 实现导出逻辑
        return nil
    }
    
    // MARK: - RSS Source Management
    
    func addRSSSource(_ source: RSSSource) {
        // 实现添加逻辑
    }
    
    func removeRSSSource(_ source: RSSSource) {
        // 实现删除逻辑
    }
    
    func refreshRSSArticles(for source: RSSSource) async {
        // 实现刷新逻辑
    }
}
