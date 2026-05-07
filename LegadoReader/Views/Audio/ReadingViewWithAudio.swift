import SwiftUI

struct ReadingViewWithAudio: View {
    @StateObject private var playerManager = AudioPlayerManager.shared
    @State private var showMiniPlayer = true
    @State private var showAudioSettings = false
    @State private var showChapterList = false
    
    let bookId = "sample_book"
    let bookName = "示例书籍"
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                readingContent
                
                Spacer()
                
                if playerManager.isMiniPlayerVisible {
                    ReadingAudioProgressView()
                }
            }
        }
        .navigationTitle(bookName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        startAudioPlayback()
                    } label: {
                        Label("开始听书", systemImage: "play.circle")
                    }
                    
                    Button {
                        showAudioSettings = true
                    } label: {
                        Label("听书设置", systemImage: "slider.horizontal.3")
                    }
                    
                    Button {
                        showChapterList = true
                    } label: {
                        Label("章节列表", systemImage: "list.bullet")
                    }
                    
                    if playerManager.isMiniPlayerVisible {
                        Button {
                            playerManager.hideMiniPlayer()
                        } label: {
                            Label("隐藏播放器", systemImage: "eye.slash")
                        }
                    } else {
                        Button {
                            playerManager.showMiniPlayer()
                        } label: {
                            Label("显示播放器", systemImage: "eye")
                        }
                    }
                } label: {
                    Image(systemName: "speaker.wave.2")
                }
            }
        }
        .sheet(isPresented: $showAudioSettings) {
            AudioSettingsView()
        }
        .sheet(isPresented: $showChapterList) {
            AudioChapterListView(bookId: bookId, bookName: bookName)
        }
        .overlay(
            MiniPlayerView(),
            alignment: .bottom
        )
    }
    
    private var readingContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("第一章 开始")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text(sampleContent)
                    .font(.body)
                    .lineSpacing(8)
                
                Divider()
                
                Text("第二章 继续")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(sampleContent2)
                    .font(.body)
                    .lineSpacing(8)
            }
            .padding()
        }
    }
    
    private func startAudioPlayback() {
        let chapters = [
            AudioPlayerManager.ChapterInfo(
                bookId: bookId,
                bookName: bookName,
                chapterId: "chapter_1",
                chapterTitle: "第一章 开始",
                duration: 300
            ),
            AudioPlayerManager.ChapterInfo(
                bookId: bookId,
                bookName: bookName,
                chapterId: "chapter_2",
                chapterTitle: "第二章 继续",
                duration: 280
            )
        ]
        
        playerManager.loadPlaylist(chapters, startIndex: 0)
        playerManager.showMiniPlayer()
    }
    
    private var sampleContent: String {
        return """
        这是一段示例文本内容，用于展示阅读界面与听书进度显示的集成效果。
        
        在阅读过程中，用户可以通过点击右上角的扬声器图标来打开听书功能。听书进度会以迷你播放器的形式显示在阅读界面底部，不会遮挡主要内容。
        
        迷你播放器提供以下功能：
        • 显示当前章节名称
        • 显示播放进度和时间
        • 快进/快退15秒
        • 播放/暂停控制
        • 点击展开查看更多控制选项
        
        用户可以随时通过上滑展开迷你播放器，查看完整的播放控制界面，包括播放速度调节、音量控制等功能。
        """
    }
    
    private var sampleContent2: String {
        return """
        这是第二章的示例内容。
        
        听书功能支持以下特性：
        • 自动保存播放进度
        • 支持后台播放
        • 支持蓝牙设备
        • 支持多种播放速度
        • 支持章节切换
        • 支持进度同步
        
        在阅读界面中，听书进度会实时更新，用户可以清楚地看到当前播放到哪个位置。
        """
    }
}

struct AudioSettingsView: View {
    @StateObject private var playerManager = AudioPlayerManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("播放设置") {
                    HStack {
                        Text("播放速度")
                        Spacer()
                        Text("\(String(format: "%.1f", playerManager.playbackRate))x")
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择速度")
                        
                        HStack(spacing: 8) {
                            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                                Button {
                                    playerManager.setPlaybackRate(Float(speed))
                                } label: {
                                    Text("\(speed, specifier: "%.2g")x")
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(abs(playerManager.playbackRate - Float(speed)) < 0.01 ? Color.blue : Color.gray.opacity(0.2))
                                        )
                                        .foregroundColor(abs(playerManager.playbackRate - Float(speed)) < 0.01 ? .white : .primary)
                                }
                            }
                        }
                    }
                }
                
                Section("音量") {
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(.secondary)
                        
                        Slider(value: $playerManager.volume, in: 0...1)
                            .tint(.blue)
                        
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("定时关闭") {
                    NavigationLink {
                        SleepTimerView()
                    } label: {
                        HStack {
                            Text("睡眠定时器")
                            Spacer()
                            Text("关闭")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("显示设置") {
                    Toggle("显示迷你播放器", isOn: $playerManager.isMiniPlayerVisible)
                    
                    Toggle("阅读时自动同步进度", isOn: .constant(true))
                    
                    Toggle("章节切换时自动播放", isOn: .constant(false))
                }
            }
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

struct SleepTimerView: View {
    @State private var selectedTime: Int = 0
    @Environment(\.dismiss) var dismiss
    
    let timeOptions = [
        (15, "15分钟后"),
        (30, "30分钟后"),
        (45, "45分钟后"),
        (60, "1小时后"),
        (90, "1.5小时后"),
        (120, "2小时后"),
        (0, "关闭")
    ]
    
    var body: some View {
        List {
            ForEach(timeOptions, id: \.0) { option in
                Button {
                    selectedTime = option.0
                    dismiss()
                } label: {
                    HStack {
                        Text(option.1)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if selectedTime == option.0 {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("睡眠定时器")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AudioChapterListView: View {
    @StateObject private var playerManager = AudioPlayerManager.shared
    @Environment(\.dismiss) var dismiss
    
    let bookId: String
    let bookName: String
    
    @State private var chapters: [AudioPlayerManager.ChapterInfo] = []
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                    Button {
                        playerManager.playChapter(at: index)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chapter.chapterTitle)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 8) {
                                    Text(formatDuration(chapter.duration))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if chapter.position > 0 {
                                        Text("已播放 \(Int(chapter.position / chapter.duration * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            if playerManager.currentIndex == index {
                                if playerManager.isPlaying {
                                    Image(systemName: "play.circle.fill")
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "pause.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(bookName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadChapters()
            }
        }
    }
    
    private func loadChapters() {
        chapters = [
            AudioPlayerManager.ChapterInfo(bookId: bookId, bookName: bookName, chapterId: "chapter_1", chapterTitle: "第一章 开始", duration: 300, position: playerManager.getSavedPosition(bookId: bookId, chapterId: "chapter_1")),
            AudioPlayerManager.ChapterInfo(bookId: bookId, bookName: bookName, chapterId: "chapter_2", chapterTitle: "第二章 继续", duration: 280, position: playerManager.getSavedPosition(bookId: bookId, chapterId: "chapter_2")),
            AudioPlayerManager.ChapterInfo(bookId: bookId, bookName: bookName, chapterId: "chapter_3", chapterTitle: "第三章 发展", duration: 320, position: playerManager.getSavedPosition(bookId: bookId, chapterId: "chapter_3")),
            AudioPlayerManager.ChapterInfo(bookId: bookId, bookName: bookName, chapterId: "chapter_4", chapterTitle: "第四章 高潮", duration: 290, position: playerManager.getSavedPosition(bookId: bookId, chapterId: "chapter_4")),
            AudioPlayerManager.ChapterInfo(bookId: bookId, bookName: bookName, chapterId: "chapter_5", chapterTitle: "第五章 结局", duration: 350, position: playerManager.getSavedPosition(bookId: bookId, chapterId: "chapter_5"))
        ]
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ReadingProgressIndicator: View {
    @StateObject private var playerManager = AudioPlayerManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.caption2)
                .foregroundColor(.blue)
            
            Text(playerManager.formattedCurrentTime)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ProgressView(value: playerManager.progress)
                .frame(width: 60)
                .tint(.blue)
            
            Text(playerManager.formattedDuration)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ReadingViewWithAudio_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ReadingViewWithAudio()
        }
    }
}
