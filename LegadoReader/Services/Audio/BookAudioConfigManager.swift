import Foundation
import AVFoundation
import Combine
import UIKit

class BookAudioConfigManager: ObservableObject {
    static let shared = BookAudioConfigManager()
    
    @Published var configs: [String: BookAudioConfig] = [:]
    @Published var defaultConfig: BookAudioConfig
    
    private let configsKey = "BookAudioConfig_configs"
    private let defaultConfigKey = "BookAudioConfig_default"
    
    struct BookAudioConfig: Codable, Identifiable, Equatable {
        let id: String
        var bookId: String?
        var voiceId: String
        var voiceName: String
        var speechRate: Double
        var speechPitch: Double
        var speechVolume: Double
        var speechStyle: String
        var chapterLevel: Int
        var autoPlayNext: Bool
        var paragraphInterval: Double
        var skipEmptyParagraphs: Bool
        var startPosition: Int
        var createdAt: Date
        var updatedAt: Date
        
        static var `default`: BookAudioConfig {
            BookAudioConfig(
                id: UUID().uuidString,
                bookId: nil,
                voiceId: "zh-CN-XiaoxiaoNeural",
                voiceName: "晓晓",
                speechRate: 1.0,
                speechPitch: 1.0,
                speechVolume: 1.0,
                speechStyle: "general",
                chapterLevel: 1,
                autoPlayNext: true,
                paragraphInterval: 0.5,
                skipEmptyParagraphs: true,
                startPosition: 0,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
        
        static func == (lhs: BookAudioConfig, rhs: BookAudioConfig) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    private init() {
        loadConfigs()
        
        if let data = UserDefaults.standard.data(forKey: defaultConfigKey),
           let saved = try? JSONDecoder().decode(BookAudioConfig.self, from: data) {
            defaultConfig = saved
        } else {
            defaultConfig = .default
        }
    }
    
    private func loadConfigs() {
        if let data = UserDefaults.standard.data(forKey: configsKey),
           let saved = try? JSONDecoder().decode([String: BookAudioConfig].self, from: data) {
            configs = saved
        }
    }
    
    private func saveConfigs() {
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: configsKey)
        }
    }
    
    func saveDefaultConfig(_ config: BookAudioConfig) {
        var newConfig = config
        newConfig.bookId = nil
        newConfig.updatedAt = Date()
        
        defaultConfig = newConfig
        
        if let data = try? JSONEncoder().encode(newConfig) {
            UserDefaults.standard.set(data, forKey: defaultConfigKey)
        }
    }
    
    func getConfig(for bookId: String) -> BookAudioConfig {
        if let config = configs[bookId] {
            return config
        }
        
        var newConfig = defaultConfig
        newConfig = BookAudioConfig(
            id: UUID().uuidString,
            bookId: bookId,
            voiceId: defaultConfig.voiceId,
            voiceName: defaultConfig.voiceName,
            speechRate: defaultConfig.speechRate,
            speechPitch: defaultConfig.speechPitch,
            speechVolume: defaultConfig.speechVolume,
            speechStyle: defaultConfig.speechStyle,
            chapterLevel: defaultConfig.chapterLevel,
            autoPlayNext: defaultConfig.autoPlayNext,
            paragraphInterval: defaultConfig.paragraphInterval,
            skipEmptyParagraphs: defaultConfig.skipEmptyParagraphs,
            startPosition: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        configs[bookId] = newConfig
        saveConfigs()
        
        return newConfig
    }
    
    func saveConfig(_ config: BookAudioConfig) {
        guard let bookId = config.bookId else { return }
        
        var newConfig = config
        newConfig.updatedAt = Date()
        
        configs[bookId] = newConfig
        saveConfigs()
    }
    
    func updateStartPosition(for bookId: String, position: Int) {
        if var config = configs[bookId] {
            config.startPosition = position
            config.updatedAt = Date()
            configs[bookId] = config
            saveConfigs()
        }
    }
    
    func updateChapterLevel(for bookId: String, level: Int) {
        if var config = configs[bookId] {
            config.chapterLevel = level
            config.updatedAt = Date()
            configs[bookId] = config
            saveConfigs()
        }
    }
    
    func deleteConfig(for bookId: String) {
        configs.removeValue(forKey: bookId)
        saveConfigs()
    }
    
    func resetToDefault(for bookId: String) {
        if let _ = configs[bookId] {
            configs.removeValue(forKey: bookId)
            saveConfigs()
        }
    }
    
    func exportConfigs() -> Data? {
        return try? JSONEncoder().encode(configs)
    }
    
    func importConfigs(from data: Data) throws {
        guard let imported = try? JSONDecoder().decode([String: BookAudioConfig].self, from: data) else {
            throw AudioConfigError.invalidFormat
        }
        
        for (bookId, config) in imported {
            configs[bookId] = config
        }
        
        saveConfigs()
    }
}

enum AudioConfigError: Error, LocalizedError {
    case invalidFormat
    case saveFailed
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "无效的配置文件格式"
        case .saveFailed: return "保存配置失败"
        case .notFound: return "未找到配置"
        }
    }
}

class AudioBookPlayer: NSObject, ObservableObject {
    static let shared = AudioBookPlayer()
    
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var currentChapterIndex = 0
    @Published var currentParagraphIndex = 0
    @Published var progress: Double = 0
    @Published var currentText = ""
    @Published var chapters: [AudioChapter] = []
    @Published var error: String?
    
    private var audioPlayer: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private let ttsManager = OnlineTTSManager.shared
    private let configManager = BookAudioConfigManager.shared
    
    private var bookId: String?
    private var currentConfig: BookAudioConfig?
    
    struct AudioChapter: Identifiable {
        let id: String
        var title: String
        var paragraphs: [String]
        var level: Int
    }
    
    override init() {
        super.init()
    }
    
    func loadBook(_ book: Book, from position: Int = 0) async throws {
        bookId = book.id
        currentConfig = configManager.getConfig(for: book.id)
        
        isLoading = true
        chapters = []
        
        let content = try await loadBookContent(book)
        
        chapters = parseChapters(content: content, maxLevel: currentConfig?.chapterLevel ?? 1)
        
        if !chapters.isEmpty {
            var paraIndex = 0
            var chapIndex = 0
            
            if position > 0 {
                let offsets = calculateParagraphOffsets()
                for (i, offset) in offsets.enumerated() {
                    if offset <= position {
                        paraIndex = i
                    }
                }
                
                var cumCount = 0
                for (i, chapter) in chapters.enumerated() {
                    if cumCount + chapter.paragraphs.count > paraIndex {
                        chapIndex = i
                        paraIndex = paraIndex - cumCount
                        break
                    }
                    cumCount += chapter.paragraphs.count
                }
            }
            
            currentChapterIndex = chapIndex
            currentParagraphIndex = paraIndex
            
            await playCurrentParagraph()
        }
        
        isLoading = false
    }
    
    private func loadBookContent(_ book: Book) async throws -> BookContent {
        return BookContent(
            title: book.name,
            author: book.author,
            chapters: [BookChapter(title: "正文", content: "", level: 1, startOffset: 0)],
            cover: nil,
            metadata: BookMetadata(),
            rawContent: ""
        )
    }
    
    private func parseChapters(content: BookContent, maxLevel: Int) -> [AudioChapter] {
        var audioChapters: [AudioChapter] = []
        
        for chapter in content.chapters {
            if chapter.level <= maxLevel || chapter.level == 0 {
                let paragraphs = splitIntoParagraphs(chapter.content)
                
                if !paragraphs.isEmpty {
                    audioChapters.append(AudioChapter(
                        id: UUID().uuidString,
                        title: chapter.title,
                        paragraphs: paragraphs,
                        level: chapter.level
                    ))
                }
            }
        }
        
        return audioChapters
    }
    
    private func splitIntoParagraphs(_ content: String) -> [String] {
        var paragraphs: [String] = []
        
        let lines = content.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if currentConfig?.skipEmptyParagraphs == true && trimmed.count < 2 { continue }
            
            let cleanLine = trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            if !cleanLine.isEmpty {
                paragraphs.append(cleanLine)
            }
        }
        
        return paragraphs
    }
    
    private func calculateParagraphOffsets() -> [Int] {
        var offsets: [Int] = []
        var offset = 0
        
        for chapter in chapters {
            for para in chapter.paragraphs {
                offsets.append(offset)
                offset += para.count + 1
            }
        }
        
        return offsets
    }
    
    func playCurrentParagraph() async {
        guard currentChapterIndex < chapters.count else {
            stop()
            return
        }
        
        let chapter = chapters[currentChapterIndex]
        guard currentParagraphIndex < chapter.paragraphs.count else {
            _ = await nextChapter()
            return
        }
        
        let text = chapter.paragraphs[currentParagraphIndex]
        currentText = text
        
        isPlaying = true
        await speak(text)
    }
    
    func speak(_ text: String) async {
        if let config = currentConfig {
            ttsManager.selectedVoice = OnlineTTSManager.OnlineVoice(
                id: config.voiceId,
                name: config.voiceName,
                language: "zh-CN",
                region: "eastasia",
                gender: .female,
                service: .azure,
                isNeural: true,
                isPremium: false,
                supportsStyles: true
            )
        }
        
        ttsManager.speak(text: text)
        
        await withCheckedContinuation { continuation in
            var observation: NSKeyValueObservation?
            observation = ttsManager.$isPlaying.observe { isPlaying in
                if !isPlaying {
                    observation?.invalidate()
                    Task {
                        await self.onParagraphFinished()
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    private func onParagraphFinished() async {
        if currentConfig?.autoPlayNext == true {
            _ = await nextParagraph()
        }
    }
    
    @MainActor
    func nextParagraph() async -> Bool {
        currentParagraphIndex += 1
        
        let chapter = chapters[currentChapterIndex]
        if currentParagraphIndex >= chapter.paragraphs.count {
            return await nextChapter()
        }
        
        await playCurrentParagraph()
        updateProgress()
        saveCurrentPosition()
        
        return true
    }
    
    @MainActor
    func previousParagraph() async -> Bool {
        currentParagraphIndex -= 1
        
        if currentParagraphIndex < 0 {
            if currentChapterIndex > 0 {
                currentChapterIndex -= 1
                currentParagraphIndex = chapters[currentChapterIndex].paragraphs.count - 1
            } else {
                currentParagraphIndex = 0
            }
        }
        
        await playCurrentParagraph()
        updateProgress()
        saveCurrentPosition()
        
        return true
    }
    
    @MainActor
    func nextChapter() async -> Bool {
        currentChapterIndex += 1
        currentParagraphIndex = 0
        
        if currentChapterIndex >= chapters.count {
            stop()
            return false
        }
        
        await playCurrentParagraph()
        updateProgress()
        saveCurrentPosition()
        
        return true
    }
    
    @MainActor
    func previousChapter() async -> Bool {
        currentChapterIndex -= 1
        currentParagraphIndex = 0
        
        if currentChapterIndex < 0 {
            currentChapterIndex = 0
            currentParagraphIndex = 0
            return false
        }
        
        await playCurrentParagraph()
        updateProgress()
        saveCurrentPosition()
        
        return true
    }
    
    @MainActor
    func jumpToChapter(_ index: Int) async {
        guard index >= 0 && index < chapters.count else { return }
        
        currentChapterIndex = index
        currentParagraphIndex = 0
        
        await playCurrentParagraph()
        updateProgress()
        saveCurrentPosition()
    }
    
    @MainActor
    func jumpToParagraph(chapter: Int, paragraph: Int) async {
        guard chapter >= 0 && chapter < chapters.count else { return }
        guard paragraph >= 0 && paragraph < chapters[chapter].paragraphs.count else { return }
        
        currentChapterIndex = chapter
        currentParagraphIndex = paragraph
        
        await playCurrentParagraph()
        updateProgress()
        saveCurrentPosition()
    }
    
    func pause() {
        ttsManager.pause()
        isPlaying = false
    }
    
    func resume() {
        ttsManager.resume()
        isPlaying = true
    }
    
    func stop() {
        ttsManager.stop()
        isPlaying = false
        currentChapterIndex = 0
        currentParagraphIndex = 0
        progress = 0
        currentText = ""
    }
    
    private func updateProgress() {
        var total = 0
        var current = 0
        
        for (i, chapter) in chapters.enumerated() {
            if i < currentChapterIndex {
                current += chapter.paragraphs.count
            }
            
            if i == currentChapterIndex {
                current += currentParagraphIndex
            }
            
            total += chapter.paragraphs.count
        }
        
        if total > 0 {
            progress = Double(current) / Double(total)
        }
    }
    
    private func saveCurrentPosition() {
        guard let bookId = bookId else { return }
        
        let offsets = calculateParagraphOffsets()
        var cumCount = 0
        
        for (i, chapter) in chapters.enumerated() {
            if i < currentChapterIndex {
                cumCount += chapter.paragraphs.count
            } else if i == currentChapterIndex {
                cumCount += currentParagraphIndex
                break
            }
        }
        
        let position = cumCount < offsets.count ? offsets[cumCount] : 0
        configManager.updateStartPosition(for: bookId, position: position)
    }
    
    func getCurrentPosition() -> Int {
        return calculateParagraphOffsets().first { $0 > 0 } ?? 0
    }
}
