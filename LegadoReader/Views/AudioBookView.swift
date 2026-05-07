import SwiftUI

struct AudioBookView: View {
    @StateObject private var audioManager = AudioBookManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingSettings = false
    @State private var showingChapterList = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 封面和标题
                CoverSection(audioManager: audioManager)
                    .padding()
                
                // 进度条
                ProgressSection(audioManager: audioManager)
                    .padding(.horizontal)
                
                Spacer()
                
                // 控制按钮
                ControlSection(audioManager: audioManager)
                    .padding()
                
                // 底部功能栏
                BottomBar(audioManager: audioManager, showingSettings: $showingSettings, showingChapterList: $showingChapterList)
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
                AudioBookSettingsView()
            }
            .sheet(isPresented: $showingChapterList) {
                AudioBookChapterListView(audioManager: audioManager)
            }
        }
    }
}

struct CoverSection: View {
    @ObservedObject var audioManager: AudioBookManager
    
    var body: some View {
        VStack(spacing: 20) {
            // 书籍封面
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
            
            // 书名和章节
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
    
    var body: some View {
        VStack(spacing: 24) {
            // 主控制按钮
            HStack(spacing: 40) {
                // 上一章
                Button(action: { audioManager.previousChapter() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.primary)
                }
                .disabled(audioManager.currentChapterIndex == 0)
                .opacity(audioManager.currentChapterIndex == 0 ? 0.5 : 1)
                
                // 快退 15 秒
                Button(action: { /* 快退 */ }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }
                
                // 播放/暂停
                Button(action: {
                    if audioManager.isPlaying {
                        audioManager.pause()
                    } else {
                        audioManager.play()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                }
                .disabled(!audioManager.isPrepared)
                .opacity(audioManager.isPrepared ? 1 : 0.5)
                
                // 快进 15 秒
                Button(action: { /* 快进 */ }) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }
                
                // 下一章
                Button(action: { audioManager.nextChapter() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.primary)
                }
                .disabled(audioManager.currentChapterIndex >= audioManager.chapters.count - 1)
                .opacity(audioManager.currentChapterIndex >= audioManager.chapters.count - 1 ? 0.5 : 1)
            }
            
            // 速度控制
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
            .padding(.horizontal)
        }
    }
}

struct BottomBar: View {
    @ObservedObject var audioManager: AudioBookManager
    @Binding var showingSettings: Bool
    @Binding var showingChapterList: Bool
    
    var body: some View {
        HStack {
            // 章节列表
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
            
            // 定时关闭
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
            
            // 设置
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
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("推荐声音") {
                    HStack(spacing: 16) {
                        ForEach(audioManager.presetVoices) { preset in
                            Button(action: {
                                audioManager.setVoice(preset.voiceIdentifier)
                            }) {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(preset.gender == .female ? Color.pink.opacity(0.2) : Color.blue.opacity(0.2))
                                            .frame(width: 60, height: 60)
                                        
                                        Image(systemName: preset.gender == .female ? "person.circle.fill" : "person.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(preset.gender == .female ? .pink : .blue)
                                    }
                                    
                                    Text(preset.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(preset.gender.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(audioManager.selectedVoice == preset.voiceIdentifier ? Color.blue.opacity(0.1) : Color.clear)
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                
                Section("朗读声音") {
                    ForEach(audioManager.getAvailableVoices()) { voice in
                        Button(action: {
                            audioManager.setVoice(voice.id)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(voice.name)
                                            .foregroundColor(.primary)
                                        if voice.gender != .unknown {
                                            Image(systemName: voice.gender == .female ? "circle.fill" : "circle.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(voice.gender == .female ? .pink : .blue)
                                        }
                                    }
                                    Text(voice.language)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if voice.id == audioManager.selectedVoice {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                                
                                if voice.isPremium {
                                    Text("增强")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.purple.opacity(0.2))
                                        .foregroundColor(.purple)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
                
                Section("朗读语速") {
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
                            // 设置定时
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
