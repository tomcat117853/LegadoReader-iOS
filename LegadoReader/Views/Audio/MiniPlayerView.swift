import SwiftUI

struct MiniPlayerView: View {
    @StateObject private var playerManager = AudioPlayerManager.shared
    @State private var isExpanded = false
    @State private var showSpeedPicker = false
    @State private var showVolumeSlider = false
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        if playerManager.isMiniPlayerVisible {
            VStack(spacing: 0) {
                if isExpanded {
                    expandedPlayer
                } else {
                    miniPlayer
                }
            }
            .background(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: -5)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private var miniPlayer: some View {
        VStack(spacing: 0) {
            progressIndicator
            
            HStack(spacing: 12) {
                bookCover
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(playerManager.currentChapter?.chapterTitle ?? "未选择章节")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(playerManager.formattedCurrentTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("/")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(playerManager.formattedDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("·")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(playerManager.progressPercentage)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button {
                        playerManager.seekBackward(15)
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    
                    Button {
                        playerManager.togglePlayPause()
                    } label: {
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                    }
                    
                    Button {
                        playerManager.seekForward(15)
                    } label: {
                        Image(systemName: "goforward.15")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
                
                Button {
                    withAnimation(.spring()) {
                        isExpanded = true
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .frame(height: 72)
    }
    
    private var expandedPlayer: some View {
        VStack(spacing: 20) {
            HStack {
                Text("听书播放器")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    withAnimation(.spring()) {
                        isExpanded = false
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            VStack(spacing: 16) {
                bookCoverLarge
                
                VStack(spacing: 8) {
                    Text(playerManager.currentChapter?.bookName ?? "")
                        .font(.headline)
                    
                    Text(playerManager.currentChapter?.chapterTitle ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 8) {
                    ProgressView(value: playerManager.progress)
                        .tint(.blue)
                    
                    HStack {
                        Text(playerManager.formattedCurrentTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(playerManager.formattedRemainingTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                HStack(spacing: 40) {
                    Button {
                        playerManager.playPrevious()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title)
                            .foregroundColor(.primary)
                    }
                    
                    Button {
                        playerManager.seekBackward(15)
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    
                    Button {
                        playerManager.togglePlayPause()
                    } label: {
                        Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)
                    }
                    
                    Button {
                        playerManager.seekForward(15)
                    } label: {
                        Image(systemName: "goforward.15")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    
                    Button {
                        playerManager.playNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title)
                            .foregroundColor(.primary)
                    }
                }
                
                HStack(spacing: 24) {
                    Button {
                        showSpeedPicker.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "speedometer")
                            Text("\(String(format: "%.1f", playerManager.playbackRate))x")
                        }
                        .font(.subheadline)
                        .foregroundColor(showSpeedPicker ? .blue : .primary)
                    }
                    
                    Button {
                        showVolumeSlider.toggle()
                    } label: {
                        Image(systemName: "speaker.wave.2")
                            .font(.title3)
                            .foregroundColor(showVolumeSlider ? .blue : .primary)
                    }
                    
                    Button {
                        playerManager.hideMiniPlayer()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                
                if showSpeedPicker {
                    speedPicker
                }
                
                if showVolumeSlider {
                    volumeSlider
                }
            }
            .padding()
            
            Spacer()
        }
        .frame(height: 420)
    }
    
    private var progressIndicator: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 2)
                
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * playerManager.progress, height: 2)
            }
        }
        .frame(height: 2)
    }
    
    private var bookCover: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.blue.opacity(0.1))
            .frame(width: 48, height: 48)
            .overlay(
                Image(systemName: "book.fill")
                    .foregroundColor(.blue)
            )
    }
    
    private var bookCoverLarge: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 200, height: 200)
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                    
                    if playerManager.isPlaying {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: 4, height: 20)
                                .animation(.easeInOut(duration: 0.3).repeatForever(), value: playerManager.isPlaying)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: 4, height: 28)
                                .animation(.easeInOut(duration: 0.3).repeatForever().delay(0.1), value: playerManager.isPlaying)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: 4, height: 16)
                                .animation(.easeInOut(duration: 0.3).repeatForever().delay(0.2), value: playerManager.isPlaying)
                        }
                    }
                }
            )
    }
    
    private var speedPicker: some View {
        VStack(spacing: 12) {
            Text("播放速度")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                    Button {
                        playerManager.setPlaybackRate(Float(speed))
                    } label: {
                        Text("\(speed, specifier: "%.2g")x")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(abs(playerManager.playbackRate - Float(speed)) < 0.01 ? Color.blue : Color.gray.opacity(0.2))
                            )
                            .foregroundColor(abs(playerManager.playbackRate - Float(speed)) < 0.01 ? .white : .primary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var volumeSlider: some View {
        VStack(spacing: 12) {
            Text("音量")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                Image(systemName: "speaker.fill")
                    .foregroundColor(.secondary)
                
                Slider(value: $playerManager.volume, in: 0...1)
                    .tint(.blue)
                
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ReadingAudioProgressView: View {
    @StateObject private var playerManager = AudioPlayerManager.shared
    @State private var showDetails = false
    
    var body: some View {
        if playerManager.isMiniPlayerVisible {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(playerManager.currentChapter?.chapterTitle ?? "")
                                .font(.caption)
                                .lineLimit(1)
                            
                            if playerManager.isPlaying {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        
                        HStack(spacing: 4) {
                            Text(playerManager.formattedCurrentTime)
                            Text("/")
                            Text(playerManager.formattedDuration)
                            Text("·")
                            Text(playerManager.progressPercentage)
                                .foregroundColor(.blue)
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        playerManager.togglePlayPause()
                    } label: {
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(6)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Button {
                        showDetails.toggle()
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground).opacity(0.95))
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * playerManager.progress)
                    }
                }
                .frame(height: 2)
            }
            .sheet(isPresented: $showDetails) {
                MiniPlayerView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

struct AudioProgressOverlay: View {
    @StateObject private var playerManager = AudioPlayerManager.shared
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("正在播放")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(playerManager.currentChapter?.chapterTitle ?? "未选择章节")
                        .font(.headline)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 8) {
                ProgressView(value: playerManager.progress)
                    .tint(.blue)
                
                HStack {
                    Text(playerManager.formattedCurrentTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(playerManager.formattedRemainingTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 24) {
                Button {
                    playerManager.seekBackward(15)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "gobackward.15")
                        Text("后退15秒")
                            .font(.caption2)
                    }
                    .foregroundColor(.primary)
                }
                
                Button {
                    playerManager.togglePlayPause()
                } label: {
                    Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.blue)
                }
                
                Button {
                    playerManager.seekForward(15)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "goforward.15")
                        Text("前进15秒")
                            .font(.caption2)
                    }
                    .foregroundColor(.primary)
                }
            }
            
            HStack(spacing: 16) {
                Button {
                    playerManager.playPrevious()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "backward.fill")
                        Text("上一章")
                    }
                    .font(.caption)
                    .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button {
                    playerManager.playNext()
                } label: {
                    HStack(spacing: 4) {
                        Text("下一章")
                        Image(systemName: "forward.fill")
                    }
                    .font(.caption)
                    .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.15), radius: 10)
        .padding()
    }
}

struct MiniPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            MiniPlayerView()
        }
    }
}
