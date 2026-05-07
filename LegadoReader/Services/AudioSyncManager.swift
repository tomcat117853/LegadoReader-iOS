import Foundation
import Combine

class AudioSyncManager: BaseService, ObservableObject {
    static let shared = AudioSyncManager()
    
    @Published var syncEnabled: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncInterval: TimeInterval = 300
    @Published var isSyncing: Bool = false
    @Published var syncError: String?
    @Published var autoSyncOnWifi: Bool = true
    @Published var syncQueue: [SyncTask] = []
    
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    struct SyncTask: Identifiable, Codable {
        let id: String
        let bookId: String
        let chapterIndex: Int
        let position: TimeInterval
        let timestamp: Date
        var isSynced: Bool
    }
    
    private let syncTasksKey = "AudioSyncManager_tasks"
    private let settingsKey = "AudioSyncManager_settings"
    
    private init() {
        super.init()
        loadSettings()
        loadSyncTasks()
        startSyncTimer()
        setupNetworkMonitoring()
    }
    
    var pendingSyncCount: Int {
        return syncQueue.filter { !$0.isSynced }.count
    }
    
    var hasPendingSync: Bool {
        return pendingSyncCount > 0
    }
    
    func addSyncTask(bookId: String, chapterIndex: Int, position: TimeInterval) {
        let task = SyncTask(
            id: UUID().uuidString,
            bookId: bookId,
            chapterIndex: chapterIndex,
            position: position,
            timestamp: Date(),
            isSynced: false
        )
        
        syncQueue.removeAll { $0.bookId == bookId && $0.chapterIndex == chapterIndex }
        syncQueue.append(task)
        saveSyncTasks()
        
        if syncEnabled {
            Task {
                await syncNow()
            }
        }
    }
    
    func syncNow() async {
        guard !isSyncing else { return }
        
        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        
        do {
            for task in syncQueue where !task.isSynced {
                try await syncTaskToServer(task)
            }
            
            for i in syncQueue.indices {
                syncQueue[i].isSynced = true
            }
            
            saveSyncTasks()
            
            await MainActor.run {
                lastSyncTime = Date()
                isSyncing = false
            }
            
            logInfo("Audio sync completed: \(syncQueue.count) tasks")
        } catch {
            await MainActor.run {
                syncError = error.localizedDescription
                isSyncing = false
            }
            logError("Audio sync failed: \(error)")
        }
    }
    
    private func syncTaskToServer(_ task: SyncTask) async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
    }
    
    func getSyncProgress(for bookId: String) -> SyncProgress? {
        let tasks = syncQueue.filter { $0.bookId == bookId }
        guard !tasks.isEmpty else { return nil }
        
        let totalTasks = tasks.count
        let syncedTasks = tasks.filter { $0.isSynced }.count
        
        return SyncProgress(
            bookId: bookId,
            totalTasks: totalTasks,
            syncedTasks: syncedTasks,
            progress: Double(syncedTasks) / Double(totalTasks)
        )
    }
    
    func clearSyncHistory(for bookId: String) {
        syncQueue.removeAll { $0.bookId == bookId }
        saveSyncTasks()
    }
    
    func clearAllSyncHistory() {
        syncQueue.removeAll()
        saveSyncTasks()
    }
    
    func setSyncEnabled(_ enabled: Bool) {
        syncEnabled = enabled
        saveSettings()
        
        if enabled {
            Task {
                await syncNow()
            }
        }
    }
    
    func setSyncInterval(_ interval: TimeInterval) {
        syncInterval = max(60, min(3600, interval))
        saveSettings()
        startSyncTimer()
    }
    
    private func startSyncTimer() {
        syncTimer?.invalidate()
        
        guard syncEnabled else { return }
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.syncNow()
            }
        }
    }
    
    private func setupNetworkMonitoring() {
    }
    
    private func loadSettings() {
        if let saved = loadCodable(AudioSyncSettings.self, key: settingsKey) {
            syncEnabled = saved.syncEnabled
            syncInterval = saved.syncInterval
            autoSyncOnWifi = saved.autoSyncOnWifi
            if let lastSync = saved.lastSyncTime {
                lastSyncTime = lastSync
            }
        }
    }
    
    private func saveSettings() {
        let settings = AudioSyncSettings(
            syncEnabled: syncEnabled,
            syncInterval: syncInterval,
            autoSyncOnWifi: autoSyncOnWifi,
            lastSyncTime: lastSyncTime
        )
        saveCodable(settings, key: settingsKey)
    }
    
    private func loadSyncTasks() {
        if let saved = loadCodable([SyncTask].self, key: syncTasksKey) {
            syncQueue = saved
        }
    }
    
    private func saveSyncTasks() {
        saveCodable(syncQueue, key: syncTasksKey)
    }
}

struct AudioSyncSettings: Codable {
    var syncEnabled: Bool
    var syncInterval: TimeInterval
    var autoSyncOnWifi: Bool
    var lastSyncTime: Date?
}

struct SyncProgress {
    let bookId: String
    let totalTasks: Int
    let syncedTasks: Int
    let progress: Double
}

class AudioTimerManager: BaseService, ObservableObject {
    static let shared = AudioTimerManager()
    
    @Published var isTimerEnabled: Bool = false
    @Published var timerDuration: TimeInterval = 1800
    @Published var remainingTime: TimeInterval = 0
    @Published var timerMode: TimerMode = .countdown
    @Published var sleepReminderTime: Date?
    @Published var isTimerRunning: Bool = false
    
    private var timer: Timer?
    
    enum TimerMode: String, Codable, CaseIterable {
        case countdown = "倒计时"
        case wakeUp = "定时唤醒"
        case sleepReminder = "睡眠提醒"
        
        var icon: String {
            switch self {
            case .countdown: return "timer"
            case .wakeUp: return "alarm"
            case .sleepReminder: return "moon.zzz"
            }
        }
    }
    
    private let settingsKey = "AudioTimerManager_settings"
    
    private init() {
        super.init()
        loadSettings()
    }
    
    var formattedRemainingTime: String {
        let hours = Int(remainingTime) / 3600
        let minutes = (Int(remainingTime) % 3600) / 60
        let seconds = Int(remainingTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var formattedDuration: String {
        let hours = Int(timerDuration) / 3600
        let minutes = (Int(timerDuration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    func startTimer(duration: TimeInterval? = nil) {
        if let duration = duration {
            timerDuration = duration
        }
        
        remainingTime = timerDuration
        isTimerRunning = true
        isTimerEnabled = true
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.timerTick()
        }
        
        saveSettings()
        logInfo("Audio timer started: \(timerDuration) seconds")
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        isTimerEnabled = false
        remainingTime = 0
        
        saveSettings()
        logInfo("Audio timer stopped")
    }
    
    func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        
        saveSettings()
    }
    
    func resumeTimer() {
        guard remainingTime > 0 else { return }
        
        isTimerRunning = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.timerTick()
        }
    }
    
    func addTime(_ seconds: TimeInterval) {
        remainingTime += seconds
        timerDuration += seconds
        saveSettings()
    }
    
    func setDuration(_ duration: TimeInterval) {
        timerDuration = duration
        if !isTimerRunning {
            remainingTime = duration
        }
        saveSettings()
    }
    
    func setTimerMode(_ mode: TimerMode) {
        timerMode = mode
        saveSettings()
    }
    
    func setSleepReminder(at time: Date) {
        sleepReminderTime = time
        saveSettings()
    }
    
    private func timerTick() {
        if remainingTime > 0 {
            remainingTime -= 1
        } else {
            timerCompleted()
        }
    }
    
    private func timerCompleted() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        isTimerEnabled = false
        
        NotificationCenter.default.post(name: .audioTimerCompleted, object: nil)
        
        logInfo("Audio timer completed")
    }
    
    private func loadSettings() {
        if let saved = loadCodable(AudioTimerSettings.self, key: settingsKey) {
            timerDuration = saved.timerDuration
            timerMode = TimerMode(rawValue: saved.timerMode) ?? .countdown
            if let sleepTime = saved.sleepReminderTime {
                sleepReminderTime = sleepTime
            }
        }
    }
    
    private func saveSettings() {
        let settings = AudioTimerSettings(
            timerDuration: timerDuration,
            timerMode: timerMode.rawValue,
            sleepReminderTime: sleepReminderTime
        )
        saveCodable(settings, key: settingsKey)
    }
}

struct AudioTimerSettings: Codable {
    var timerDuration: TimeInterval
    var timerMode: String
    var sleepReminderTime: Date?
}

extension Notification.Name {
    static let audioTimerCompleted = Notification.Name("audioTimerCompleted")
}
