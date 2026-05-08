import Foundation
import UIKit

class BrightnessManager: ObservableObject {
    static let shared = BrightnessManager()
    
    @Published var brightness: CGFloat {
        didSet {
            UIScreen.main.brightness = brightness
            UserDefaults.standard.set(brightness, forKey: "BrightnessManager_brightness")
        }
    }
    
    @Published var autoBrightness = false
    @Published var nightModeEnabled = false
    @Published var nightModeBrightness: CGFloat = 0.3
    
    private init() {
        brightness = UIScreen.main.brightness
        autoBrightness = UserDefaults.standard.bool(forKey: "BrightnessManager_autoBrightness")
        nightModeEnabled = UserDefaults.standard.bool(forKey: "BrightnessManager_nightModeEnabled")
        nightModeBrightness = CGFloat(UserDefaults.standard.float(forKey: "BrightnessManager_nightModeBrightness"))
        
        if nightModeBrightness == 0 {
            nightModeBrightness = 0.3
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(brightness, forKey: "BrightnessManager_brightness")
        UserDefaults.standard.set(autoBrightness, forKey: "BrightnessManager_autoBrightness")
        UserDefaults.standard.set(nightModeEnabled, forKey: "BrightnessManager_nightModeEnabled")
        UserDefaults.standard.set(Float(nightModeBrightness), forKey: "BrightnessManager_nightModeBrightness")
    }
    
    func increaseBrightness(by amount: CGFloat = 0.05) {
        brightness = min(1.0, brightness + amount)
    }
    
    func decreaseBrightness(by amount: CGFloat = 0.05) {
        brightness = max(0.0, brightness - amount)
    }
    
    func toggleNightMode() {
        nightModeEnabled.toggle()
        
        if nightModeEnabled {
            brightness = nightModeBrightness
        }
        
        saveSettings()
    }
}

class ScreenManager: ObservableObject {
    static let shared = ScreenManager()
    
    @Published var isScreenAlwaysOn = false
    @Published var volumeButton翻页Enabled = false
    
    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        isScreenAlwaysOn = UserDefaults.standard.bool(forKey: "ScreenManager_alwaysOn")
        volumeButton翻页Enabled = UserDefaults.standard.bool(forKey: "ScreenManager_volume翻页")
    }
    
    func saveSettings() {
        UserDefaults.standard.set(isScreenAlwaysOn, forKey: "ScreenManager_alwaysOn")
        UserDefaults.standard.set(volumeButton翻页Enabled, forKey: "ScreenManager_volume翻页")
        
        UIApplication.shared.isIdleTimerDisabled = isScreenAlwaysOn
    }
}

struct BrightnessControlView: View {
    @StateObject private var brightnessManager = BrightnessManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            // 亮度图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: brightnessIcon)
                    .font(.system(size: 36))
                    .foregroundColor(.orange)
            }
            
            // 亮度滑块
            VStack(spacing: 8) {
                Slider(value: $brightnessManager.brightness, in: 0...1)
                    .tint(.orange)
                
                HStack {
                    Image(systemName: "sun.min")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(brightnessManager.brightness * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "sun.max")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // 快捷亮度
            HStack(spacing: 16) {
                BrightnessPresetButton(icon: "sun.min", label: "最低", brightness: 0.1)
                BrightnessPresetButton(icon: "sun.max", label: "正常", brightness: 0.8)
                BrightnessPresetButton(icon: "moon.fill", label: "夜间", brightness: 0.3)
            }
            
            Divider()
            
            // 夜间模式
            Toggle(isOn: $brightnessManager.nightModeEnabled) {
                HStack {
                    Image(systemName: "moon.fill")
                        .foregroundColor(.purple)
                    Text("夜间模式")
                }
            }
            .onChange(of: brightnessManager.nightModeEnabled) { _ in
                brightnessManager.saveSettings()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
    }
    
    private var brightnessIcon: String {
        if brightnessManager.brightness < 0.3 {
            return "sun.min"
        } else if brightnessManager.brightness < 0.7 {
            return "sun.max"
        } else {
            return "sun.max.fill"
        }
    }
}

struct BrightnessPresetButton: View {
    let icon: String
    let label: String
    let brightness: CGFloat
    
    @StateObject private var brightnessManager = BrightnessManager.shared
    
    var isSelected: Bool {
        abs(brightnessManager.brightness - brightness) < 0.1
    }
    
    var body: some View {
        Button(action: {
            brightnessManager.brightness = brightness
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .orange : .secondary)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(isSelected ? .orange : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.orange.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
    }
}

struct BrightnessSettingsView: View {
    @StateObject private var brightnessManager = BrightnessManager.shared
    @StateObject private var screenManager = ScreenManager.shared
    
    var body: some View {
        List {
            Section("亮度设置") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sun.min")
                            .foregroundColor(.secondary)
                        
                        Slider(value: $brightnessManager.brightness, in: 0...1)
                            .tint(.orange)
                        
                        Image(systemName: "sun.max")
                            .foregroundColor(.secondary)
                    }
                    
                    Text("当前亮度: \(Int(brightnessManager.brightness * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                
                Toggle("自动调节亮度", isOn: $brightnessManager.autoBrightness)
                    .onChange(of: brightnessManager.autoBrightness) { _ in
                        brightnessManager.saveSettings()
                    }
            }
            
            Section("夜间模式") {
                Toggle("启用夜间模式", isOn: $brightnessManager.nightModeEnabled)
                    .onChange(of: brightnessManager.nightModeEnabled) { _ in
                        brightnessManager.saveSettings()
                    }
                
                if brightnessManager.nightModeEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("夜间模式亮度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(value: $brightnessManager.nightModeBrightness, in: 0.1...0.5)
                            .tint(.purple)
                        
                        Text("夜间模式将自动设置为此亮度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section("屏幕设置") {
                Toggle("屏幕常亮", isOn: $screenManager.isScreenAlwaysOn)
                    .onChange(of: screenManager.isScreenAlwaysOn) { _ in
                        screenManager.saveSettings()
                    }
                
                Toggle("音量键翻页", isOn: $screenManager.volumeButton翻页Enabled)
                    .onChange(of: screenManager.volumeButton翻页Enabled) { _ in
                        screenManager.saveSettings()
                    }
            }
            
            Section("快捷设置") {
                HStack {
                    Text("快捷调光")
                    Spacer()
                    Text("上下滑动右侧边缘")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("双指滑动手势")
                    Spacer()
                    Text("任意位置双指上下滑动")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("快捷夜间模式")
                    Spacer()
                    Text("三指双击")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("亮度与屏幕")
    }
}
