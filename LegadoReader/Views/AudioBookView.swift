import SwiftUI

struct AudioBookView: View {
    @StateObject private var audioManager = AudioBookManager.shared
    @StateObject private var onlineTTS = OnlineTTSManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingSettings = false
    @State private var showingChapterList = false
    @State private var isUsingOnlineTTS = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                CoverSection(audioManager: audioManager, onlineTTS: onlineTTS)
                    .padding()
                
                ProgressSection(audioManager: audioManager)
                    .padding(.horizontal)
                
                Spacer()
                
                ControlSection(audioManager: audioManager, onlineTTS: onlineTTS, isUsingOnlineTTS: $isUsingOnlineTTS)
                    .padding()
                
                BottomBar(audioManager: audioManager, showingSettings: $showingSettings, showingChapterList: $showingChapterList, isUsingOnlineTTS: $isUsingOnlineTTS)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            .background(Color(.systemBackground))
            .navigationTitle("听书")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                AudioBookSettingsView(isUsingOnlineTTS: $isUsingOnlineTTS)
            }
            .sheet(isPresented: $showingChapterList) {
                AudioBookChapterListView(audioManager: audioManager)
            }
        }
    }
}

struct CoverSection: View {
    @ObservedObject var audioManager: AudioBookManager
    @ObservedObject var onlineTTS: OnlineTTSManager
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 180, height: 240)
                    .shadow(radius: 10)
                
                VStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("听书模式")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            
            VStack(spacing: 8) {
                Text(audioManager.currentBookName.isEmpty ? "未选择书籍" : audioManager.currentBookName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text(audioManager.currentChapterTitle.isEmpty ? "请选择章节" : audioManager.currentChapterTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if onlineTTS.isPlaying {
                    HStack(spacing: 4) {
                        Image(systemName: "wifi")
                            .font(.caption2)
                        Text("在线语音")
                            .font(.caption2)
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
}

struct ProgressSection: View {
    @ObservedObject var audioManager: AudioBookManager
    
    var body: some View {
        VStack(spacing: 8) {
            // 进度条
            ProgressView(value: audioManager.progress)
                .progressViewStyle(.linear)
                .tint(.blue)
                .scaleEffect(y: 2)
            
            // 时间显示
            HStack {
                Text(audioManager.formatTime(audioManager.getElapsedTime()))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                
                Spacer()
                
                Text("第 \(audioManager.currentChapterIndex + 1)/\(audioManager.chapters.count) 章")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("剩余 \(audioManager.formatTime(audioManager.estimateRemainingTime()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

struct ControlSection: View {
    @ObservedObject var audioManager: AudioBookManager
    @ObservedObject var onlineTTS: OnlineTTSManager
    @Binding var isUsingOnlineTTS: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 40) {
                Button(action: { audioManager.previousChapter() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.primary)
                }
                .disabled(audioManager.currentChapterIndex == 0)
                .opacity(audioManager.currentChapterIndex == 0 ? 0.5 : 1)
                
                Button(action: { /* 快退 */ }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }
                
                Button(action: {
                    if isUsingOnlineTTS {
                        if onlineTTS.isPlaying {
                            onlineTTS.pause()
                        } else if onlineTTS.currentText.isEmpty {
                            onlineTTS.speak(text: audioManager.currentText)
                        } else {
                            onlineTTS.resume()
                        }
                    } else {
                        if audioManager.isPlaying {
                            audioManager.pause()
                        } else {
                            audioManager.play()
                        }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(isUsingOnlineTTS && onlineTTS.isLoading ? Color.gray : Color.blue)
                            .frame(width: 70, height: 70)
                        
                        if isUsingOnlineTTS && onlineTTS.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: getPlayButtonIcon())
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(!audioManager.isPrepared && !isUsingOnlineTTS)
                .opacity(audioManager.isPrepared || isUsingOnlineTTS ? 1 : 0.5)
                
                Button(action: { /* 快进 */ }) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }
                
                Button(action: { audioManager.nextChapter() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.primary)
                }
                .disabled(audioManager.currentChapterIndex >= audioManager.chapters.count - 1)
                .opacity(audioManager.currentChapterIndex >= audioManager.chapters.count - 1 ? 0.5 : 1)
            }
            
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Text(isUsingOnlineTTS ? "在线语音" : "本地语音")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("语音类型", selection: $isUsingOnlineTTS) {
                        Text("本地").tag(false)
                        Text("在线").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    
                    Spacer()
                }
                
                if isUsingOnlineTTS {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("当前声音")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(onlineTTS.selectedVoice.name)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            HStack {
                                Text("朗读风格")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(onlineTTS.speechStyle.displayName)
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 16) {
                        Text("语速")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(
                            value: Binding(
                                get: { Double(audioManager.speechRate) },
                                set: { audioManager.setSpeed(Float($0)) }
                            ),
                            in: Double(AVSpeechUtteranceMinimumSpeechRate)...Double(AVSpeechUtteranceMaximumSpeechRate)
                        )
                        .tint(.blue)
                        
                        Text(audioManager.formatSpeed(audioManager.speechRate))
                            .font(.caption)
                            .foregroundColor(.blue)
                            .monospacedDigit()
                            .frame(width: 50)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func getPlayButtonIcon() -> String {
        if isUsingOnlineTTS {
            return onlineTTS.isPlaying ? "pause.fill" : "play.fill"
        } else {
            return audioManager.isPlaying ? "pause.fill" : "play.fill"
        }
    }
}

struct BottomBar: View {
    @ObservedObject var audioManager: AudioBookManager
    @Binding var showingSettings: Bool
    @Binding var showingChapterList: Bool
    @Binding var isUsingOnlineTTS: Bool
    
    var body: some View {
        HStack {
            Button(action: { showingChapterList = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20))
                    Text("目录")
                        .font(.caption2)
                }
                .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            
            Button(action: { /* 定时关闭 */ }) {
                VStack(spacing: 4) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 20))
                    Text("定时")
                        .font(.caption2)
                }
                .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            
            Button(action: { /* 语音切换提示 */ }) {
                VStack(spacing: 4) {
                    Image(systemName: isUsingOnlineTTS ? "wifi" : "iphone")
                        .font(.system(size: 20))
                    Text(isUsingOnlineTTS ? "在线" : "本地")
                        .font(.caption2)
                }
                .foregroundColor(isUsingOnlineTTS ? .green : .primary)
            }
            .frame(maxWidth: .infinity)
            
            Button(action: { showingSettings = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20))
                    Text("设置")
                        .font(.caption2)
                }
                .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }
}

struct AudioBookSettingsView: View {
    @StateObject private var audioManager = AudioBookManager.shared
    @StateObject private var onlineTTS = OnlineTTSManager.shared
    @Binding var isUsingOnlineTTS: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Toggle("使用在线语音合成", isOn: $isUsingOnlineTTS)
                } header: {
                    Text("语音类型")
                } footer: {
                    Text("在线语音使用网络服务，支持更多有感情的声音")
                }
                
                if isUsingOnlineTTS {
                    Section("在线声音") {
                        ForEach(onlineTTS.getChineseVoices()) { voice in
                            Button(action: {
                                onlineTTS.selectVoice(voice)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(voice.name)
                                                .foregroundColor(.primary)
                                            if voice.isNeural {
                                                Text("神经网络")
                                                    .font(.caption2)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 2)
                                                    .background(Color.blue.opacity(0.2))
                                                    .foregroundColor(.blue)
                                                    .cornerRadius(4)
                                            }
                                        }
                                        Text("\(voice.language) • \(voice.service.rawValue)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if voice.id == onlineTTS.selectedVoice.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    
                    Section("朗读风格") {
                        ForEach(onlineTTS.getAvailableStyles()) { style in
                            Button(action: {
                                onlineTTS.speechStyle = style
                            }) {
                                HStack {
                                    Text(style.displayName)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if style == onlineTTS.speechStyle {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    
                    Section("在线服务设置") {
                        NavigationLink(destination: OnlineTTSConfigView()) {
                            HStack {
                                Image(systemName: "gear")
                                    .foregroundColor(.blue)
                                Text("API 配置")
                            }
                        }
                    }
                }
                
                Section("本地声音") {
                    ForEach(audioManager.presetVoices) { preset in
                        Button(action: {
                            audioManager.setVoice(preset.voiceIdentifier)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(preset.name)
                                            .foregroundColor(.primary)
                                        Image(systemName: preset.gender == .female ? "person.circle.fill" : "person.circle.fill")
                                            .foregroundColor(preset.gender == .female ? .pink : .blue)
                                    }
                                    Text(preset.gender.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if audioManager.selectedVoice == preset.voiceIdentifier {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section("本地朗读语速") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("当前语速")
                            Spacer()
                            Text(audioManager.formatSpeed(audioManager.speechRate))
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(audioManager.speechRate) },
                                set: { audioManager.setSpeed(Float($0)) }
                            ),
                            in: Double(AVSpeechUtteranceMinimumSpeechRate)...Double(AVSpeechUtteranceMaximumSpeechRate)
                        )
                        .tint(.blue)
                        
                        HStack {
                            Text("慢")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("快")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("快捷语速") {
                    ForEach(audioManager.getSpeedOptions(), id: \.1) { option in
                        Button(action: {
                            audioManager.setSpeed(option.1)
                        }) {
                            HStack {
                                Text(option.0)
                                    .foregroundColor(.primary)
                                Spacer()
                                if abs(audioManager.speechRate - option.1) < 0.01 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section("本地音调") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("音调")
                            Spacer()
                            Text(audioManager.getPitchOptions().first { abs(audioManager.pitchMultiplier - $0.1) < 0.01 }?.0 ?? "自定义")
                                .foregroundColor(.green)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(audioManager.pitchMultiplier) },
                                set: { audioManager.setPitch(Float($0)) }
                            ),
                            in: 0.5...2.0
                        )
                        .tint(.green)
                        
                        HStack {
                            Text("低沉")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("高亢")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("音量") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("当前音量")
                            Spacer()
                            Text("\(Int(audioManager.volume * 100))%")
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(audioManager.volume) },
                                set: { audioManager.setVolume(Float($0)) }
                            ),
                            in: 0...1
                        )
                        .tint(.blue)
                        
                        HStack {
                            Image(systemName: "speaker.fill")
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("定时关闭") {
                    ForEach(["关闭", "15 分钟", "30 分钟", "45 分钟", "60 分钟", "章节结束"], id: \.self) { option in
                        Button(action: {
                            
                        }) {
                            HStack {
                                Text(option)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("听书设置")
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
}

struct OnlineTTSConfigView: View {
    @StateObject private var onlineTTS = OnlineTTSManager.shared
    @State private var azureApiKey = ""
    @State private var azureRegion = "eastasia"
    
    var body: some View {
        List {
            Section {
                TextField("API Key", text: $azureApiKey)
                    .textContentType(.password)
                    .autocapitalization(.none)
            } header: {
                Text("微软 Azure API")
            } footer: {
                Text("输入您的 Azure 语音服务 API Key 以使用更多高质量声音")
            }
            
            Section("区域") {
                Picker("选择区域", selection: $azureRegion) {
                    Text("东亚 (eastasia)").tag("eastasia")
                    Text("东南亚 (southeastasia)").tag("southeastasia")
                    Text("美国东部 (eastus)").tag("eastus")
                    Text("西欧 (westeurope)").tag("westeurope")
                }
            }
            
            Section {
                Button("保存配置") {
                    var config = OnlineTTSManager.TTSConfig.default
                    config.azureApiKey = azureApiKey
                    config.azureRegion = azureRegion
                    onlineTTS.saveConfig(config)
                }
                .foregroundColor(.blue)
            }
        }
        .navigationTitle("API 配置")
    }
}

struct AudioBookChapterListView: View {
    @ObservedObject var audioManager: AudioBookManager
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var filteredChapters: [Chapter] {
        if searchText.isEmpty {
            return audioManager.chapters
        }
        return audioManager.chapters.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredChapters.indices, id: \.self) { index in
                    let chapter = filteredChapters[index]
                    Button(action: {
                        audioManager.setChapter(index)
                        dismiss()
                    }) {
                        HStack {
                            Text("\(index + 1). \(chapter.title)")
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            Spacer()
                            
                            if index == audioManager.currentChapterIndex {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("选择章节")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索章节")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AudioBookMiniPlayerView: View {
    @StateObject private var audioManager = AudioBookManager.shared
    
    var body: some View {
        if audioManager.isPlaying || audioManager.isPaused {
            HStack(spacing: 12) {
                // 封面
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "waveform")
                        .foregroundColor(.blue)
                }
                
                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(audioManager.currentBookName)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    
                    Text(audioManager.currentChapterTitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    ProgressView(value: audioManager.progress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                }
                
                // 控制按钮
                HStack(spacing: 16) {
                    Button(action: {
                        if audioManager.isPlaying {
                            audioManager.pause()
                        } else {
                            audioManager.play()
                        }
                    }) {
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.primary)
                    }
                    
                    Button(action: {
                        audioManager.stop()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 5)
            .padding()
        }
    }
}
