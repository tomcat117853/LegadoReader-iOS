import SwiftUI

struct EyeCareSettingsView: View {
    @StateObject private var eyeCareManager = EyeCareManager.shared
    @State private var showingBreakAlert = false
    @State private var showingStatsView = false
    
    var body: some View {
        NavigationView {
            Form {
                enableSection
                presetSection
                filterSection
                displaySection
                breakReminderSection
                statisticsSection
            }
            .navigationTitle("护眼模式")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingStatsView) {
                EyeCareStatisticsView()
            }
            .alert("休息提醒", isPresented: $eyeCareManager.showingBreakNotification) {
                Button("稍后提醒(5分钟)") {
                    eyeCareManager.snoozeBreak(5)
                }
                Button("跳过") {
                    eyeCareManager.skipBreak()
                }
                Button("开始休息") {
                    eyeCareManager.endBreak()
                }
            } message: {
                Text("您已连续阅读\(eyeCareManager.breakReminderInterval)分钟，建议休息一下保护眼睛！")
            }
        }
    }
    
    private var enableSection: some View {
        Section {
            Toggle("启用护眼模式", isOn: Binding(
                get: { eyeCareManager.isEyeCareEnabled },
                set: { _ in eyeCareManager.toggleEyeCare() }
            ))
            .tint(.green)
            
            if eyeCareManager.isEyeCareEnabled {
                HStack {
                    VStack(alignment: .leading) {
                        Text("当前模式")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(getCurrentModeName())
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        } header: {
            Text("护眼模式")
        } footer: {
            Text("护眼模式通过过滤蓝光、调整色温、对比度来减少眼睛疲劳")
        }
    }
    
    private var presetSection: some View {
        Section {
            ForEach(EyeCarePreset.allCases, id: \.self) { preset in
                Button(action: { eyeCareManager.applyPreset(preset) }) {
                    HStack {
                        Image(systemName: preset.icon)
                            .foregroundColor(presetColor(preset))
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text(preset.rawValue)
                                .foregroundColor(.primary)
                            Text(preset.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if isCurrentPreset(preset) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        } header: {
            Text("快速预设")
        }
    }
    
    private var filterSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("蓝光过滤")
                    Spacer()
                    Text("\(Int(eyeCareManager.blueLightFilterLevel * 100))%")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $eyeCareManager.blueLightFilterLevel, in: 0...1, step: 0.05)
                    .tint(.blue)
                    .onChange(of: eyeCareManager.blueLightFilterLevel) { _, newValue in
                        eyeCareManager.setBlueLightFilter(newValue)
                    }
            }
            .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("暖色色温")
                    Spacer()
                    Text("\(Int(eyeCareManager.warmLightLevel * 100))%")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $eyeCareManager.warmLightLevel, in: 0...1, step: 0.05)
                    .tint(.orange)
                    .onChange(of: eyeCareManager.warmLightLevel) { _, newValue in
                        eyeCareManager.setWarmLight(newValue)
                    }
            }
            .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("对比度")
                    Spacer()
                    Text(String(format: "%.1fx", eyeCareManager.contrastLevel))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $eyeCareManager.contrastLevel, in: 0.8...1.5, step: 0.05)
                    .tint(.gray)
                    .onChange(of: eyeCareManager.contrastLevel) { _, newValue in
                        eyeCareManager.setContrast(newValue)
                    }
            }
            .padding(.vertical, 4)
        } header: {
            Text("滤镜设置")
        } footer: {
            Text("调整蓝光过滤和暖色调以减少眼睛疲劳")
        }
    }
    
    private var displaySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("字体大小")
                    Spacer()
                    Text(String(format: "%.0f%%", eyeCareManager.fontSizeMultiplier * 100))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $eyeCareManager.fontSizeMultiplier, in: 0.8...1.5, step: 0.1)
                    .tint(.blue)
                    .onChange(of: eyeCareManager.fontSizeMultiplier) { _, newValue in
                        eyeCareManager.setFontSize(newValue)
                    }
            }
            .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("行间距")
                    Spacer()
                    Text(String(format: "%.1fx", eyeCareManager.lineSpacingMultiplier))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $eyeCareManager.lineSpacingMultiplier, in: 1.0...2.0, step: 0.1)
                    .tint(.blue)
                    .onChange(of: eyeCareManager.lineSpacingMultiplier) { _, newValue in
                        eyeCareManager.setLineSpacing(newValue)
                    }
            }
            .padding(.vertical, 4)
            
            previewSection
        } header: {
            Text("显示设置")
        }
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("预览效果")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(eyeCareManager.effectiveBackgroundColor)
                    .frame(height: 80)
                
                Text("这是一段示例文字，用于预览护眼效果。保护眼睛，从现在开始。")
                    .font(.system(size: 14 * eyeCareManager.fontSizeMultiplier))
                    .foregroundColor(eyeCareManager.effectiveTextColor)
                    .lineSpacing(4 * eyeCareManager.lineSpacingMultiplier)
                    .padding(8)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.vertical, 4)
    }
    
    private var breakReminderSection: some View {
        Section {
            Toggle("休息提醒", isOn: Binding(
                get: { eyeCareManager.isBreakReminderEnabled },
                set: { _ in
                    if eyeCareManager.isBreakReminderEnabled {
                        eyeCareManager.disableBreakReminder()
                    } else {
                        eyeCareManager.enableBreakReminder()
                    }
                }
            ))
            .tint(.orange)
            
            if eyeCareManager.isBreakReminderEnabled {
                Stepper("阅读\(eyeCareManager.breakReminderInterval)分钟后提醒", 
                       value: $eyeCareManager.breakReminderInterval,
                       in: 10...60,
                       step: 5)
                    .onChange(of: eyeCareManager.breakReminderInterval) { _, newValue in
                        eyeCareManager.setBreakReminderInterval(newValue)
                    }
                
                Stepper("休息时长\(eyeCareManager.breakDuration)秒", 
                       value: $eyeCareManager.breakDuration,
                       in: 10...300,
                       step: 10)
                    .onChange(of: eyeCareManager.breakDuration) { _, newValue in
                        eyeCareManager.setBreakDuration(newValue)
                    }
                
                if let lastBreak = eyeCareManager.lastBreakTime {
                    HStack {
                        Text("上次休息")
                        Spacer()
                        Text(lastBreak.formatted(date: .abbreviated, time: .shortened))
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("休息提醒")
        } footer: {
            Text("定时提醒休息，帮助保护眼睛健康")
        }
    }
    
    private var statisticsSection: some View {
        Section {
            Button(action: { showingStatsView = true }) {
                HStack {
                    Image(systemName: "chart.bar")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    
                    Text("查看统计数据")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("今日阅读时长")
                Spacer()
                Text(eyeCareManager.readingTimeFormatted)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("今日听书时长")
                Spacer()
                Text(eyeCareManager.listeningTimeFormatted)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("今日总时长")
                Spacer()
                Text(eyeCareManager.todayTotalTimeFormatted)
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
            }
            
            HStack {
                Text("护眼模式启用次数")
                Spacer()
                Text("\(eyeCareManager.eyeCareSessions)")
                    .foregroundColor(.secondary)
            }
            
            Button(role: .destructive, action: {
                eyeCareManager.resetDailyStats()
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 30)
                    Text("重置今日统计")
                }
            }
        } header: {
            Text("统计")
        }
    }
    
    private func getCurrentModeName() -> String {
        if !eyeCareManager.isEyeCareEnabled {
            return "已关闭"
        }
        
        if eyeCareManager.blueLightFilterLevel > 0.7 {
            return "强效护眼"
        } else if eyeCareManager.blueLightFilterLevel > 0.4 {
            return "中度护眼"
        } else if eyeCareManager.blueLightFilterLevel > 0 {
            return "轻度护眼"
        }
        
        return "已启用"
    }
    
    private func presetColor(_ preset: EyeCarePreset) -> Color {
        switch preset {
        case .off: return .gray
        case .light: return .yellow
        case .medium: return .orange
        case .strong: return .red
        case .night: return .indigo
        case .reading: return .blue
        }
    }
    
    private func isCurrentPreset(_ preset: EyeCarePreset) -> Bool {
        if !eyeCareManager.isEyeCareEnabled && preset == .off {
            return true
        }
        
        if eyeCareManager.isEyeCareEnabled {
            switch preset {
            case .light:
                return eyeCareManager.blueLightFilterLevel > 0.1 && eyeCareManager.blueLightFilterLevel <= 0.3
            case .medium:
                return eyeCareManager.blueLightFilterLevel > 0.3 && eyeCareManager.blueLightFilterLevel <= 0.5
            case .strong:
                return eyeCareManager.blueLightFilterLevel > 0.5 && eyeCareManager.blueLightFilterLevel <= 0.7
            case .night:
                return eyeCareManager.blueLightFilterLevel > 0.7
            case .reading:
                return eyeCareManager.fontSizeMultiplier > 1.0 && eyeCareManager.lineSpacingMultiplier > 1.3
            default:
                return false
            }
        }
        
        return false
    }
}

struct EyeCareStatisticsView: View {
    @StateObject private var eyeCareManager = EyeCareManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    todayStatsCard
                    weeklyStatsCard
                    eyeCareTipsCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("护眼统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var todayStatsCard: some View {
        VStack(spacing: 16) {
            Text("今日统计")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                StatBox(
                    title: "阅读",
                    value: eyeCareManager.readingTimeFormatted,
                    icon: "book.fill",
                    color: .blue
                )
                
                StatBox(
                    title: "听书",
                    value: eyeCareManager.listeningTimeFormatted,
                    icon: "headphones",
                    color: .purple
                )
            }
            
            HStack(spacing: 20) {
                StatBox(
                    title: "总计",
                    value: eyeCareManager.todayTotalTimeFormatted,
                    icon: "clock.fill",
                    color: .green
                )
                
                StatBox(
                    title: "护眼次数",
                    value: "\(eyeCareManager.eyeCareSessions)",
                    icon: "eye.fill",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var weeklyStatsCard: some View {
        VStack(spacing: 16) {
            Text("本周趋势")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            let weeklyStats = eyeCareManager.getWeeklyStats()
            
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(weeklyStats.enumerated()), id: \.offset) { index, stats in
                    VStack {
                        WeeklyBar(
                            value: stats.readingTime + stats.listeningTime,
                            maxValue: weeklyStats.map { $0.readingTime + $0.listeningTime }.max() ?? 1,
                            isToday: index == weeklyStats.count - 1
                        )
                        
                        Text(dayLabel(for: index))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 120)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var eyeCareTipsCard: some View {
        VStack(spacing: 12) {
            Text("护眼建议")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 8) {
                TipRow(icon: "20.circle", text: "每阅读20分钟，远眺20英尺外20秒")
                TipRow(icon: "sun.max", text: "保持适当屏幕亮度，避免过亮或过暗")
                TipRow(icon: "textformat.size", text: "选择合适的字体大小，减少眼睛负担")
                TipRow(icon: "moon.stars", text: "夜间使用护眼模式，避免蓝光影响睡眠")
                TipRow(icon: "figure.walk", text: "定时休息，做眼保健操或户外活动")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func dayLabel(for index: Int) -> String {
        let days = ["日", "一", "二", "三", "四", "五", "六"]
        let dayIndex = Calendar.current.component(.weekday, from: Date()) - 1
        let targetDayIndex = (dayIndex - (6 - index) + 7) % 7
        return days[targetDayIndex]
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct WeeklyBar: View {
    let value: TimeInterval
    let maxValue: TimeInterval
    let isToday: Bool
    
    var body: some View {
        GeometryReader { geometry in
            let height = maxValue > 0 ? CGFloat(value / maxValue) * geometry.size.height : 0
            
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(isToday ? Color.blue : Color.blue.opacity(0.5))
                    .frame(height: max(height, 4))
            }
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}
