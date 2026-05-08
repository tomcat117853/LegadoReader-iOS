import Foundation
import SwiftUI
import Combine

class EyeCareManager: BaseService, ObservableObject {
    static let shared = EyeCareManager()
    
    @Published var isEyeCareEnabled: Bool = false
    @Published var blueLightFilterLevel: Double = 0.0
    @Published var warmLightLevel: Double = 0.0
    @Published var contrastLevel: Double = 1.0
    @Published var fontSizeMultiplier: Double = 1.0
    @Published var lineSpacingMultiplier: Double = 1.2
    @Published var isBreakReminderEnabled: Bool = false
    @Published var breakReminderInterval: Int = 20
    @Published var breakDuration: Int = 20
    @Published var readingTimeToday: TimeInterval = 0
    @Published var listeningTimeToday: TimeInterval = 0
    @Published var lastBreakTime: Date?
    @Published var totalEyeCareTime: TimeInterval = 0
    @Published var eyeCareSessions: Int = 0
    @Published var currentSessionStartTime: Date?
    @Published var autoBrightnessEnabled: Bool = false
    @Published var customBrightness: Double = 0.5
    @Published var isAutoMode: Bool = true
    @Published var scheduledEyeCareStart: Date?
    @Published var scheduledEyeCareEnd: Date?
    @Published var showingBreakNotification: Bool = false
    
    private let settingsKey = "EyeCareManager_settings"
    private let statsKey = "EyeCareManager_stats"
    private var timer: Timer?
    private var breakTimer: Timer?
    
    struct EyeCareSettings: Codable {
        var isEyeCareEnabled: Bool
        var blueLightFilterLevel: Double
        var warmLightLevel: Double
        var contrastLevel: Double
        var fontSizeMultiplier: Double
        var lineSpacingMultiplier: Double
        var isBreakReminderEnabled: Bool
        var breakReminderInterval: Int
        var breakDuration: Int
        var autoBrightnessEnabled: Bool
        var customBrightness: Double
        var isAutoMode: Bool
    }
    
    struct EyeCareStats: Codable {
        var readingTimeToday: TimeInterval
        var listeningTimeToday: TimeInterval
        var totalEyeCareTime: TimeInterval
        var eyeCareSessions: Int
        var lastSessionDate: Date?
        var dailyStats: [String: DailyStats]
    }
    
    struct DailyStats: Codable {
        var date: String
        var readingTime: TimeInterval
        var listeningTime: TimeInterval
        var eyeCareEnabledTime: TimeInterval
        var breakCount: Int
    }
    
    private var settings: EyeCareSettings
    private var stats: EyeCareStats
    
    private init() {
        settings = EyeCareSettings(
            isEyeCareEnabled: false,
            blueLightFilterLevel: 0.0,
            warmLightLevel: 0.0,
            contrastLevel: 1.0,
            fontSizeMultiplier: 1.0,
            lineSpacingMultiplier: 1.2,
            isBreakReminderEnabled: false,
            breakReminderInterval: 20,
            breakDuration: 20,
            autoBrightnessEnabled: false,
            customBrightness: 0.5,
            isAutoMode: true
        )
        
        stats = EyeCareStats(
            readingTimeToday: 0,
            listeningTimeToday: 0,
            totalEyeCareTime: 0,
            eyeCareSessions: 0,
            lastSessionDate: nil,
            dailyStats: [:]
        )
        
        super.init()
        loadSettings()
        loadStats()
        checkAndResetDailyStats()
        startSessionTracking()
    }
    
    var effectiveBackgroundColor: Color {
        if !isEyeCareEnabled {
            return Color(hex: "#FFFFFF")
        }
        
        let warmEffect = warmLightLevel * 0.3
        let blueReduction = blueLightFilterLevel * 0.2
        
        return Color(
            red: 1.0 - blueReduction * 0.3,
            green: 1.0 - blueReduction * 0.1,
            blue: warmEffect * 0.7
        )
    }
    
    var effectiveTextColor: Color {
        if !isEyeCareEnabled {
            return Color(hex: "#1C1C1E")
        }
        
        let warmEffect = warmLightLevel * 0.4
        
        return Color(
            red: 0.15 + warmEffect * 0.2,
            green: 0.12 + warmEffect * 0.15,
            blue: 0.1 + warmEffect * 0.05
        )
    }
    
    var overlayOpacity: Double {
        return blueLightFilterLevel * 0.15 + warmLightLevel * 0.1
    }
    
    var overlayColor: Color {
        return Color(
            red: 1.0,
            green: 0.85 - blueLightFilterLevel * 0.2,
            blue: 0.6 - warmLightLevel * 0.3
        )
    }
    
    var effectiveContrast: Double {
        return isEyeCareEnabled ? contrastLevel : 1.0
    }
    
    var todayTotalTime: TimeInterval {
        return readingTimeToday + listeningTimeToday
    }
    
    var todayTotalTimeFormatted: String {
        return formatDuration(todayTotalTime)
    }
    
    var readingTimeFormatted: String {
        return formatDuration(readingTimeToday)
    }
    
    var listeningTimeFormatted: String {
        return formatDuration(listeningTimeToday)
    }
    
    var totalEyeCareTimeFormatted: String {
        return formatDuration(totalEyeCareTime)
    }
    
    var breakRecommendation: String {
        if readingTimeToday + listeningTimeToday > 3600 {
            return "您今天已阅读超过1小时，建议休息10-15分钟"
        } else if readingTimeToday + listeningTimeToday > 1800 {
            return "已阅读较长时间，记得适时休息，保护眼睛"
        } else {
            return "继续保持良好的阅读习惯"
        }
    }
    
    func enableEyeCare() {
        isEyeCareEnabled = true
        eyeCareSessions += 1
        currentSessionStartTime = Date()
        saveSettings()
        logInfo("Eye care mode enabled")
    }
    
    func disableEyeCare() {
        if let startTime = currentSessionStartTime {
            let sessionDuration = Date().timeIntervalSince(startTime)
            totalEyeCareTime += sessionDuration
        }
        isEyeCareEnabled = false
        currentSessionStartTime = nil
        saveSettings()
        logInfo("Eye care mode disabled")
    }
    
    func toggleEyeCare() {
        if isEyeCareEnabled {
            disableEyeCare()
        } else {
            enableEyeCare()
        }
    }
    
    func setBlueLightFilter(_ level: Double) {
        blueLightFilterLevel = max(0, min(1, level))
        warmLightLevel = max(0, min(1, warmLightLevel - blueLightFilterLevel * 0.5))
        saveSettings()
    }
    
    func setWarmLight(_ level: Double) {
        warmLightLevel = max(0, min(1, level))
        blueLightFilterLevel = max(0, min(1, blueLightFilterLevel - warmLightLevel * 0.5))
        saveSettings()
    }
    
    func setContrast(_ level: Double) {
        contrastLevel = max(0.8, min(1.5, level))
        saveSettings()
    }
    
    func setFontSize(_ multiplier: Double) {
        fontSizeMultiplier = max(0.8, min(1.5, multiplier))
        saveSettings()
    }
    
    func setLineSpacing(_ multiplier: Double) {
        lineSpacingMultiplier = max(1.0, min(2.0, multiplier))
        saveSettings()
    }
    
    func enableBreakReminder() {
        isBreakReminderEnabled = true
        lastBreakTime = Date()
        startBreakTimer()
        saveSettings()
        logInfo("Break reminder enabled")
    }
    
    func disableBreakReminder() {
        isBreakReminderEnabled = false
        breakTimer?.invalidate()
        breakTimer = nil
        saveSettings()
        logInfo("Break reminder disabled")
    }
    
    func setBreakReminderInterval(_ minutes: Int) {
        breakReminderInterval = max(10, min(60, minutes))
        if isBreakReminderEnabled {
            startBreakTimer()
        }
        saveSettings()
    }
    
    func setBreakDuration(_ seconds: Int) {
        breakDuration = max(10, min(300, seconds))
        saveSettings()
    }
    
    func snoozeBreak(_ minutes: Int = 5) {
        lastBreakTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
        showingBreakNotification = false
        startBreakTimer()
    }
    
    func skipBreak() {
        lastBreakTime = Date()
        showingBreakNotification = false
        startBreakTimer()
    }
    
    func startBreak() {
        showingBreakNotification = true
    }
    
    func endBreak() {
        showingBreakNotification = false
        lastBreakTime = Date()
        startBreakTimer()
    }
    
    func addReadingTime(_ seconds: TimeInterval) {
        readingTimeToday += seconds
        saveStats()
    }
    
    func addListeningTime(_ seconds: TimeInterval) {
        listeningTimeToday += seconds
        saveStats()
    }
    
    func resetDailyStats() {
        readingTimeToday = 0
        listeningTimeToday = 0
        saveStats()
    }
    
    func resetAllStats() {
        readingTimeToday = 0
        listeningTimeToday = 0
        totalEyeCareTime = 0
        eyeCareSessions = 0
        saveStats()
    }
    
    func getWeeklyStats() -> [DailyStats] {
        var weeklyStats: [DailyStats] = []
        let calendar = Calendar.current
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                let dateString = formatDate(date)
                if let dayStats = stats.dailyStats[dateString] {
                    weeklyStats.append(dayStats)
                } else {
                    weeklyStats.append(DailyStats(date: dateString, readingTime: 0, listeningTime: 0, eyeCareEnabledTime: 0, breakCount: 0))
                }
            }
        }
        
        return weeklyStats.reversed()
    }
    
    func scheduleEyeCare(start: Date, end: Date) {
        scheduledEyeCareStart = start
        scheduledEyeCareEnd = end
        saveSettings()
    }
    
    func cancelScheduledEyeCare() {
        scheduledEyeCareStart = nil
        scheduledEyeCareEnd = nil
        saveSettings()
    }
    
    func applyPreset(_ preset: EyeCarePreset) {
        switch preset {
        case .off:
            isEyeCareEnabled = false
            blueLightFilterLevel = 0
            warmLightLevel = 0
            contrastLevel = 1.0
            
        case .light:
            isEyeCareEnabled = true
            blueLightFilterLevel = 0.2
            warmLightLevel = 0.1
            contrastLevel = 1.0
            
        case .medium:
            isEyeCareEnabled = true
            blueLightFilterLevel = 0.4
            warmLightLevel = 0.3
            contrastLevel = 1.05
            
        case .strong:
            isEyeCareEnabled = true
            blueLightFilterLevel = 0.6
            warmLightLevel = 0.5
            contrastLevel = 1.1
            
        case .night:
            isEyeCareEnabled = true
            blueLightFilterLevel = 0.8
            warmLightLevel = 0.7
            contrastLevel = 1.15
            
        case .reading:
            isEyeCareEnabled = true
            blueLightFilterLevel = 0.3
            warmLightLevel = 0.2
            contrastLevel = 1.05
            fontSizeMultiplier = 1.1
            lineSpacingMultiplier = 1.4
        }
        saveSettings()
    }
    
    private func startSessionTracking() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.saveStats()
        }
    }
    
    private func startBreakTimer() {
        breakTimer?.invalidate()
        
        guard isBreakReminderEnabled else { return }
        
        let interval = TimeInterval(breakReminderInterval * 60)
        
        breakTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.startBreak()
        }
    }
    
    private func checkAndResetDailyStats() {
        let today = formatDate(Date())
        
        for (dateString, _) in stats.dailyStats {
            if dateString != today {
                stats.dailyStats.removeValue(forKey: dateString)
            }
        }
        
        saveStats()
    }
    
    private func saveSettings() {
        settings = EyeCareSettings(
            isEyeCareEnabled: isEyeCareEnabled,
            blueLightFilterLevel: blueLightFilterLevel,
            warmLightLevel: warmLightLevel,
            contrastLevel: contrastLevel,
            fontSizeMultiplier: fontSizeMultiplier,
            lineSpacingMultiplier: lineSpacingMultiplier,
            isBreakReminderEnabled: isBreakReminderEnabled,
            breakReminderInterval: breakReminderInterval,
            breakDuration: breakDuration,
            autoBrightnessEnabled: autoBrightnessEnabled,
            customBrightness: customBrightness,
            isAutoMode: isAutoMode
        )
        
        saveCodable(settings, key: settingsKey)
    }
    
    private func loadSettings() {
        if let saved = loadCodable(EyeCareSettings.self, key: settingsKey) {
            isEyeCareEnabled = saved.isEyeCareEnabled
            blueLightFilterLevel = saved.blueLightFilterLevel
            warmLightLevel = saved.warmLightLevel
            contrastLevel = saved.contrastLevel
            fontSizeMultiplier = saved.fontSizeMultiplier
            lineSpacingMultiplier = saved.lineSpacingMultiplier
            isBreakReminderEnabled = saved.isBreakReminderEnabled
            breakReminderInterval = saved.breakReminderInterval
            breakDuration = saved.breakDuration
            autoBrightnessEnabled = saved.autoBrightnessEnabled
            customBrightness = saved.customBrightness
            isAutoMode = saved.isAutoMode
        }
    }
    
    private func saveStats() {
        let today = formatDate(Date())
        
        stats.readingTimeToday = readingTimeToday
        stats.listeningTimeToday = listeningTimeToday
        stats.totalEyeCareTime = totalEyeCareTime
        stats.eyeCareSessions = eyeCareSessions
        stats.lastSessionDate = currentSessionStartTime
        
        if var todayStats = stats.dailyStats[today] {
            todayStats.readingTime = readingTimeToday
            todayStats.listeningTime = listeningTimeToday
            todayStats.eyeCareEnabledTime = isEyeCareEnabled ? todayStats.eyeCareEnabledTime + 60 : todayStats.eyeCareEnabledTime
            stats.dailyStats[today] = todayStats
        } else {
            stats.dailyStats[today] = DailyStats(
                date: today,
                readingTime: readingTimeToday,
                listeningTime: listeningTimeToday,
                eyeCareEnabledTime: isEyeCareEnabled ? 60 : 0,
                breakCount: 0
            )
        }
        
        saveCodable(stats, key: statsKey)
    }
    
    private func loadStats() {
        if let saved = loadCodable(EyeCareStats.self, key: statsKey) {
            stats = saved
            readingTimeToday = saved.readingTimeToday
            listeningTimeToday = saved.listeningTimeToday
            totalEyeCareTime = saved.totalEyeCareTime
            eyeCareSessions = saved.eyeCareSessions
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else if minutes > 0 {
            return "\(minutes)分钟"
        } else {
            return "< 1分钟"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

enum EyeCarePreset: String, CaseIterable {
    case off = "关闭"
    case light = "轻度"
    case medium = "中度"
    case strong = "强效"
    case night = "夜间"
    case reading = "阅读模式"
    
    var description: String {
        switch self {
        case .off: return "关闭护眼模式"
        case .light: return "轻度过滤蓝光，略微暖色"
        case .medium: return "中度过滤，适合一般使用"
        case .strong: return "强效过滤，适合长时间阅读"
        case .night: return "夜间模式，极度护眼"
        case .reading: return "阅读优化，减少眼睛疲劳"
        }
    }
    
    var icon: String {
        switch self {
        case .off: return "eye.slash"
        case .light: return "sun.haze"
        case .medium: return "sun.max"
        case .strong: return "sun.min"
        case .night: return "moon.stars"
        case .reading: return "book"
        }
    }
}
