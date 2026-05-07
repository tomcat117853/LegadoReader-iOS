import Foundation
import UserNotifications
import Combine
import BackgroundTasks

class UpdateNotificationManager: NSObject, ObservableObject {
    static let shared = UpdateNotificationManager()
    
    @Published var isEnabled = false
    @Published var checkInterval: CheckInterval = .hourly
    @Published var lastCheckTime: Date?
    @Published var pendingUpdates: [BookUpdate] = []
    @Published var subscribedBooks: [SubscribedBook] = []
    @Published var isChecking = false
    
    private let defaults = UserDefaults.standard
    private var checkTimer: Timer?
    private var cancellables = Set<AnyCurable>()
    
    enum CheckInterval: String, CaseIterable, Identifiable {
        case halfHour = "30min"
        case hourly = "1hour"
        case twoHours = "2hours"
        case sixHours = "6hours"
        case daily = "1day"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .halfHour: return "30分钟"
            case .hourly: return "1小时"
            case .twoHours: return "2小时"
            case .sixHours: return "6小时"
            case .daily: return "每天"
            }
        }
        
        var seconds: TimeInterval {
            switch self {
            case .halfHour: return 30 * 60
            case .hourly: return 60 * 60
            case .twoHours: return 2 * 60 * 60
            case .sixHours: return 6 * 60 * 60
            case .daily: return 24 * 60 * 60
            }
        }
    }
    
    struct SubscribedBook: Identifiable, Codable, Equatable {
        let id: String
        let bookName: String
        let author: String
        let sourceUrl: String
        let lastChapter: String
        let lastChapterIndex: Int
        var subscribeTime: Date
        var lastCheckTime: Date
        var isNotifying: Bool
        var notifyNewChapter: Bool
        var notifyChapterCount: Int
        
        init(book: Book, source: BookSource, lastChapter: Chapter) {
            self.id = UUID().uuidString
            self.bookName = book.name
            self.author = book.author
            self.sourceUrl = source.url
            self.lastChapter = lastChapter.title
            self.lastChapterIndex = lastChapter.index
            self.subscribeTime = Date()
            self.lastCheckTime = Date()
            self.isNotifying = true
            self.notifyNewChapter = true
            self.notifyChapterCount = 0
        }
    }
    
    struct BookUpdate: Identifiable, Codable {
        let id: String
        let bookId: String
        let bookName: String
        let oldChapter: String
        let newChapter: String
        let newChapterIndex: Int
        let updateTime: Date
        var isRead: Bool
        
        init(bookId: String, bookName: String, oldChapter: String, newChapter: String, newChapterIndex: Int) {
            self.id = UUID().uuidString
            self.bookId = bookId
            self.bookName = bookName
            self.oldChapter = oldChapter
            self.newChapter = newChapter
            self.newChapterIndex = newChapterIndex
            self.updateTime = Date()
            self.isRead = false
        }
    }
    
    override init() {
        super.init()
        loadSettings()
        loadSubscribedBooks()
        requestNotificationPermission()
    }
    
    private func loadSettings() {
        isEnabled = defaults.bool(forKey: "UpdateNotification_enabled")
        if let intervalString = defaults.string(forKey: "UpdateNotification_interval"),
           let interval = CheckInterval(rawValue: intervalString) {
            checkInterval = interval
        }
        if let lastCheck = defaults.object(forKey: "UpdateNotification_lastCheck") as? Date {
            lastCheckTime = lastCheck
        }
    }
    
    private func loadSubscribedBooks() {
        if let data = defaults.data(forKey: "UpdateNotification_subscribedBooks"),
           let books = try? JSONDecoder().decode([SubscribedBook].self, from: data) {
            subscribedBooks = books
        }
    }
    
    private func saveSettings() {
        defaults.set(isEnabled, forKey: "UpdateNotification_enabled")
        defaults.set(checkInterval.rawValue, forKey: "UpdateNotification_interval")
        defaults.set(lastCheckTime, forKey: "UpdateNotification_lastCheck")
    }
    
    func saveSubscribedBooks() {
        if let data = try? JSONEncoder().encode(subscribedBooks) {
            defaults.set(data, forKey: "UpdateNotification_subscribedBooks")
        }
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        saveSettings()
        
        if enabled {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }
    
    func setCheckInterval(_ interval: CheckInterval) {
        checkInterval = interval
        saveSettings()
        
        if isEnabled {
            stopMonitoring()
            startMonitoring()
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("通知权限请求失败: \(error.localizedDescription)")
            }
        }
    }
    
    func checkNotificationPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    func startMonitoring() {
        stopMonitoring()
        
        checkTimer = Timer.scheduledTimer(withTimeInterval: checkInterval.seconds, repeats: true) { [weak self] _ in
            self?.checkForUpdates()
        }
        
        checkForUpdates()
    }
    
    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
    
    func checkForUpdates() {
        guard !isChecking else { return }
        guard !subscribedBooks.isEmpty else { return }
        
        isChecking = true
        
        Task {
            var updates: [BookUpdate] = []
            
            for subscribedBook in subscribedBooks {
                if let update = await checkBookUpdate(subscribedBook) {
                    updates.append(update)
                }
            }
            
            await MainActor.run {
                self.lastCheckTime = Date()
                self.saveSettings()
                self.isChecking = false
                
                if !updates.isEmpty {
                    self.pendingUpdates.append(contentsOf: updates)
                    self.processUpdates(updates)
                }
            }
        }
    }
    
    private func checkBookUpdate(_ subscribedBook: SubscribedBook) async -> BookUpdate? {
        do {
            let url = URL(string: subscribedBook.sourceUrl)!
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            
            if let catalogRule = getCatalogRule(for: subscribedBook.sourceUrl),
               let newChapterIndex = extractLatestChapterIndex(from: html, rule: catalogRule) {
                
                if newChapterIndex > subscribedBook.lastChapterIndex {
                    if let newChapter = await fetchChapterTitle(subscribedBook.sourceUrl, index: newChapterIndex) {
                        let update = BookUpdate(
                            bookId: subscribedBook.id,
                            bookName: subscribedBook.bookName,
                            oldChapter: subscribedBook.lastChapter,
                            newChapter: newChapter,
                            newChapterIndex: newChapterIndex
                        )
                        
                        await updateSubscribedBook(subscribedBook, newChapter: newChapter, newIndex: newChapterIndex)
                        
                        return update
                    }
                }
            }
            
            return nil
        } catch {
            return nil
        }
    }
    
    private func getCatalogRule(for sourceUrl: String) -> String? {
        return ".chapter-list a"
    }
    
    private func extractLatestChapterIndex(from html: String, rule: String) -> Int? {
        let pattern = "href=\"([^\"]+)\"[^>]*>第?(\\d+)章"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: range)
        
        var maxIndex = 0
        
        for match in matches {
            if match.numberOfRanges >= 2,
               let indexRange = Range(match.range(at: 1), in: html),
               let indexStr = html[indexRange].split(separator: ' ').last,
               let index = Int(indexStr) {
                maxIndex = max(maxIndex, index)
            }
        }
        
        return maxIndex > 0 ? maxIndex : nil
    }
    
    private func fetchChapterTitle(_ sourceUrl: String, index: Int) async -> String? {
        return "第\(index)章"
    }
    
    private func updateSubscribedBook(_ subscribedBook: SubscribedBook, newChapter: String, newIndex: Int) async {
        await MainActor.run {
            if let index = subscribedBooks.firstIndex(where: { $0.id == subscribedBook.id }) {
                subscribedBooks[index].lastChapter = newChapter
                subscribedBooks[index].lastChapterIndex = newIndex
                subscribedBooks[index].lastCheckTime = Date()
                subscribedBooks[index].notifyChapterCount += 1
                saveSubscribedBooks()
            }
        }
    }
    
    private func processUpdates(_ updates: [BookUpdate]) {
        for update in updates {
            sendNotification(for: update)
        }
        
        updateAppBadge()
    }
    
    func sendNotification(for update: BookUpdate) {
        let content = UNMutableNotificationContent()
        content.title = "📚 \(update.bookName) 更新啦！"
        content.body = "新章节：\(update.newChapter)"
        content.sound = .default
        content.badge = NSNumber(value: pendingUpdates.filter { !$0.isRead }.count)
        content.userInfo = [
            "bookId": update.bookId,
            "updateId": update.id,
            "type": "bookUpdate"
        ]
        
        let request = UNNotificationRequest(
            identifier: update.id,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("发送通知失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateAppBadge() {
        let unreadCount = pendingUpdates.filter { !$0.isRead }.count
        
        UNUserNotificationCenter.current().setBadgeCount(unreadCount) { error in
            if let error = error {
                print("更新角标失败: \(error.localizedDescription)")
            }
        }
    }
    
    func subscribeBook(_ book: Book, source: BookSource, chapter: Chapter) {
        let subscribedBook = SubscribedBook(book: book, source: source, lastChapter: chapter)
        subscribedBooks.append(subscribedBook)
        saveSubscribedBooks()
        
        sendSubscriptionNotification(for: subscribedBook)
    }
    
    func unsubscribeBook(_ bookId: String) {
        subscribedBooks.removeAll { $0.id == bookId }
        saveSubscribedBooks()
    }
    
    func isSubscribed(_ bookId: String) -> Bool {
        return subscribedBooks.contains { $0.bookId == bookId }
    }
    
    func getSubscribedBook(_ bookId: String) -> SubscribedBook? {
        return subscribedBooks.first { $0.bookId == bookId }
    }
    
    private func sendSubscriptionNotification(for subscribedBook: SubscribedBook) {
        let content = UNMutableNotificationContent()
        content.title = "✅ 追书成功！"
        content.body = "已开启【\(subscribedBook.bookName)】的更新提醒"
        content.sound = .default
        content.userInfo = [
            "bookId": subscribedBook.id,
            "type": "subscription"
        ]
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func markUpdateAsRead(_ updateId: String) {
        if let index = pendingUpdates.firstIndex(where: { $0.id == updateId }) {
            pendingUpdates[index].isRead = true
            updateAppBadge()
        }
    }
    
    func markAllAsRead() {
        for index in pendingUpdates.indices {
            pendingUpdates[index].isRead = true
        }
        updateAppBadge()
    }
    
    func clearUpdates() {
        pendingUpdates.removeAll()
        updateAppBadge()
    }
    
    func removeUpdate(_ updateId: String) {
        pendingUpdates.removeAll { $0.id == updateId }
        updateAppBadge()
    }
    
    func getUnreadUpdates() -> [BookUpdate] {
        return pendingUpdates.filter { !$0.isRead }
    }
    
    func getUnreadCount() -> Int {
        return pendingUpdates.filter { !$0.isRead }.count
    }
}

extension UpdateNotificationManager {
    func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: "com.legadoreader.updatenotify")
        request.earliestBeginDate = Date(timeIntervalSinceNow: checkInterval.seconds)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("无法注册后台任务: \(error.localizedDescription)")
        }
    }
    
    func handleBackgroundTask(_ task: BGAppRefreshTask) {
        scheduleBackgroundTask()
        
        task.expirationHandler = {
            self.stopMonitoring()
        }
        
        checkForUpdates()
        
        task.setTaskCompleted(success: true)
    }
}
