import Foundation
import AVFoundation
import Combine

class AudioPlayerManager: BaseService {
    static let shared = AudioPlayerManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var progress: Double = 0
    @Published var playbackRate: Float = 1.0
    @Published var currentChapter: ChapterInfo?
    @Published var playlist: [ChapterInfo] = []
    @Published var currentIndex: Int = 0
    @Published var volume: Float = 1.0
    @Published var isMiniPlayerVisible = false
    @Published var audioSourceType: AudioSourceType = .local
    @Published var isStreamingFromWebSocket = false
    @Published var webSocketConnected = false
    
    enum AudioSourceType: String {
        case local = "local"
        case websocket = "websocket"
        case httpStream = "http_stream"
    }
    
    struct ChapterInfo: Identifiable, Codable {
        let id: String
        let bookId: String
        let bookName: String
        let chapterId: String
        let chapterTitle: String
        let audioURL: URL?
        let localPath: String?
        let duration: TimeInterval
        let position: TimeInterval
        
        init(bookId: String, bookName: String, chapterId: String, chapterTitle: String, audioURL: URL? = nil, localPath: String? = nil, duration: TimeInterval = 0, position: TimeInterval = 0) {
            self.id = UUID().uuidString
            self.bookId = bookId
            self.bookName = bookName
            self.chapterId = chapterId
            self.chapterTitle = chapterTitle
            self.audioURL = audioURL
            self.localPath = localPath
            self.duration = duration
            self.position = position
        }
    }
    
    private override init() {
        super.init()
        setupAudioSession()
        loadSavedState()
        setupWebSocketObservers()
    }
    
    private func setupWebSocketObservers() {
        NotificationCenter.default.publisher(for: .webSocketDidConnect)
            .sink { [weak self] _ in
                self?.webSocketConnected = true
                self?.logInfo("WebSocket connected for audio streaming")
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .webSocketDidDisconnect)
            .sink { [weak self] _ in
                self?.webSocketConnected = false
                self?.logInfo("WebSocket disconnected")
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .audioStreamUrlReceived)
            .sink { [weak self] notification in
                if let urlString = notification.object as? String,
                   let url = URL(string: urlString) {
                    self?.loadStreamingAudio(from: url)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .audioStreamComplete)
            .sink { [weak self] notification in
                if let audioData = notification.object as? Data {
                    self?.handleStreamComplete(data: audioData)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.allowBluetooth, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setActive(true)
            
            NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
        } catch {
            logError("Failed to setup audio session: \(error)")
        }
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            pause()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    play()
                }
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            pause()
        default:
            break
        }
    }
    
    private func loadSavedState() {
        if let savedIndex = storageManager.integer(forKey: "AudioPlayer_currentIndex") as Int?,
           savedIndex >= 0 {
            currentIndex = savedIndex
        }
        
        if let savedVolume = storageManager.string(forKey: "AudioPlayer_volume"),
           let volumeValue = Float(savedVolume) {
            volume = volumeValue
        }
        
        if let savedRate = storageManager.string(forKey: "AudioPlayer_playbackRate"),
           let rateValue = Float(savedRate) {
            playbackRate = rateValue
        }
        
        isMiniPlayerVisible = storageManager.bool(forKey: "AudioPlayer_miniPlayerVisible")
    }
    
    private func saveState() {
        storageManager.set(currentIndex, forKey: "AudioPlayer_currentIndex")
        storageManager.set("\(volume)", forKey: "AudioPlayer_volume")
        storageManager.set("\(playbackRate)", forKey: "AudioPlayer_playbackRate")
        storageManager.set(isMiniPlayerVisible, forKey: "AudioPlayer_miniPlayerVisible")
    }
    
    func loadPlaylist(_ chapters: [ChapterInfo], startIndex: Int = 0) {
        playlist = chapters
        currentIndex = startIndex
        
        if let chapter = chapters[safe: startIndex] {
            currentChapter = chapter
            loadChapter(chapter)
        }
        
        saveState()
    }
    
    private func loadChapter(_ chapter: ChapterInfo) {
        stopTimer()
        
        var url: URL?
        
        if let localPath = chapter.localPath {
            url = URL(fileURLWithPath: localPath)
        } else if let audioURL = chapter.audioURL {
            url = audioURL
        }
        
        guard let audioURL = url else {
            logError("No valid audio URL for chapter: \(chapter.chapterTitle)")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.rate = playbackRate
            audioPlayer?.volume = volume
            
            duration = audioPlayer?.duration ?? 0
            
            if chapter.position > 0 {
                audioPlayer?.currentTime = chapter.position
                currentTime = chapter.position
            }
            
            updateProgress()
            showMiniPlayer()
        } catch {
            logError("Failed to load audio: \(error)")
        }
    }
    
    func loadStreamingAudio(from url: URL) {
        stopTimer()
        isStreamingFromWebSocket = true
        
        logInfo("Loading streaming audio from: \(url.absoluteString)")
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.rate = playbackRate
            audioPlayer?.volume = volume
            
            duration = audioPlayer?.duration ?? 0
            updateProgress()
            showMiniPlayer()
        } catch {
            logError("Failed to load streaming audio: \(error)")
        }
    }
    
    private func handleStreamComplete(data: Data) {
        logInfo("Stream complete, received \(data.count) bytes")
        
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.rate = playbackRate
            audioPlayer?.volume = volume
            
            duration = audioPlayer?.duration ?? 0
            isStreamingFromWebSocket = false
        } catch {
            logError("Failed to create audio player from stream data: \(error)")
        }
    }
    
    func play() {
        guard let player = audioPlayer else { return }
        
        player.play()
        player.rate = playbackRate
        isPlaying = true
        startTimer()
        saveState()
        
        NotificationCenter.default.post(name: .audioPlayerDidStartPlaying, object: nil)
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
        saveCurrentPosition()
        saveState()
        
        NotificationCenter.default.post(name: .audioPlayerDidPause, object: nil)
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        stopTimer()
        currentTime = 0
        progress = 0
        hideMiniPlayer()
        isStreamingFromWebSocket = false
        
        NotificationCenter.default.post(name: .audioPlayerDidStop, object: nil)
    }
    
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        
        player.currentTime = max(0, min(time, duration))
        currentTime = player.currentTime
        updateProgress()
        saveCurrentPosition()
    }
    
    func seekForward(_ seconds: TimeInterval = 15) {
        seek(to: currentTime + seconds)
    }
    
    func seekBackward(_ seconds: TimeInterval = 15) {
        seek(to: currentTime - seconds)
    }
    
    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        audioPlayer?.rate = rate
        saveState()
    }
    
    func setVolume(_ value: Float) {
        volume = value
        audioPlayer?.volume = value
        saveState()
    }
    
    func playNext() {
        guard currentIndex < playlist.count - 1 else { return }
        
        saveCurrentPosition()
        currentIndex += 1
        
        if let chapter = playlist[safe: currentIndex] {
            currentChapter = chapter
            loadChapter(chapter)
            play()
        }
        
        saveState()
        
        NotificationCenter.default.post(name: .audioPlayerDidChangeChapter, object: nil)
    }
    
    func playPrevious() {
        guard currentIndex > 0 else {
            seek(to: 0)
            return
        }
        
        saveCurrentPosition()
        currentIndex -= 1
        
        if let chapter = playlist[safe: currentIndex] {
            currentChapter = chapter
            loadChapter(chapter)
            play()
        }
        
        saveState()
        
        NotificationCenter.default.post(name: .audioPlayerDidChangeChapter, object: nil)
    }
    
    func playChapter(at index: Int) {
        guard index >= 0 && index < playlist.count else { return }
        
        saveCurrentPosition()
        currentIndex = index
        
        if let chapter = playlist[safe: index] {
            currentChapter = chapter
            loadChapter(chapter)
            play()
        }
        
        saveState()
        
        NotificationCenter.default.post(name: .audioPlayerDidChangeChapter, object: nil)
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updatePlaybackTime()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updatePlaybackTime() {
        guard let player = audioPlayer else { return }
        
        currentTime = player.currentTime
        updateProgress()
        
        if currentTime > 0 && Int(currentTime) % 10 == 0 {
            saveCurrentPosition()
        }
    }
    
    private func updateProgress() {
        guard duration > 0 else {
            progress = 0
            return
        }
        progress = currentTime / duration
    }
    
    private func saveCurrentPosition() {
        guard let chapter = currentChapter else { return }
        
        let updatedChapter = ChapterInfo(
            bookId: chapter.bookId,
            bookName: chapter.bookName,
            chapterId: chapter.chapterId,
            chapterTitle: chapter.chapterTitle,
            audioURL: chapter.audioURL,
            localPath: chapter.localPath,
            duration: duration,
            position: currentTime
        )
        
        if let index = playlist.firstIndex(where: { $0.chapterId == chapter.chapterId }) {
            playlist[index] = updatedChapter
        }
        
        currentChapter = updatedChapter
        
        saveCodable(updatedChapter, key: "AudioPlayer_position_\(chapter.bookId)_\(chapter.chapterId)")
    }
    
    func getSavedPosition(bookId: String, chapterId: String) -> TimeInterval {
        if let chapter = loadCodable(ChapterInfo.self, key: "AudioPlayer_position_\(bookId)_\(chapterId)") {
            return chapter.position
        }
        return 0
    }
    
    func showMiniPlayer() {
        isMiniPlayerVisible = true
        saveState()
    }
    
    func hideMiniPlayer() {
        isMiniPlayerVisible = false
        saveState()
    }
    
    func toggleMiniPlayer() {
        isMiniPlayerVisible.toggle()
        saveState()
    }
    
    var formattedCurrentTime: String {
        return formatTime(currentTime)
    }
    
    var formattedDuration: String {
        return formatTime(duration)
    }
    
    var formattedRemainingTime: String {
        return formatTime(duration - currentTime)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var progressPercentage: String {
        return String(format: "%.1f%%", progress * 100)
    }
    
    func getProgressInfo() -> AudioProgressInfo {
        return AudioProgressInfo(
            isPlaying: isPlaying,
            currentTime: currentTime,
            duration: duration,
            progress: progress,
            playbackRate: playbackRate,
            currentChapter: currentChapter?.chapterTitle ?? "",
            currentIndex: currentIndex,
            totalChapters: playlist.count,
            formattedCurrentTime: formattedCurrentTime,
            formattedDuration: formattedDuration,
            formattedRemainingTime: formattedRemainingTime,
            progressPercentage: progressPercentage,
            audioSourceType: audioSourceType,
            isStreaming: isStreamingFromWebSocket,
            webSocketConnected: webSocketConnected
        )
    }
    
    struct AudioProgressInfo {
        let isPlaying: Bool
        let currentTime: TimeInterval
        let duration: TimeInterval
        let progress: Double
        let playbackRate: Float
        let currentChapter: String
        let currentIndex: Int
        let totalChapters: Int
        let formattedCurrentTime: String
        let formattedDuration: String
        let formattedRemainingTime: String
        let progressPercentage: String
        let audioSourceType: AudioSourceType
        let isStreaming: Bool
        let webSocketConnected: Bool
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if currentIndex < playlist.count - 1 {
            playNext()
        } else {
            stop()
            NotificationCenter.default.post(name: .audioPlayerDidFinishPlaylist, object: nil)
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        logError("Audio decode error: \(error?.localizedDescription ?? "Unknown error")")
        NotificationCenter.default.post(name: .audioPlayerDidEncounterError, object: error)
    }
}

extension Notification.Name {
    static let audioPlayerDidStartPlaying = Notification.Name("audioPlayerDidStartPlaying")
    static let audioPlayerDidPause = Notification.Name("audioPlayerDidPause")
    static let audioPlayerDidStop = Notification.Name("audioPlayerDidStop")
    static let audioPlayerDidChangeChapter = Notification.Name("audioPlayerDidChangeChapter")
    static let audioPlayerDidFinishPlaylist = Notification.Name("audioPlayerDidFinishPlaylist")
    static let audioPlayerDidEncounterError = Notification.Name("audioPlayerDidEncounterError")
    static let audioPlayerProgressDidUpdate = Notification.Name("audioPlayerProgressDidUpdate")
    static let webSocketDidConnect = Notification.Name("webSocketDidConnect")
    static let webSocketDidDisconnect = Notification.Name("webSocketDidDisconnect")
    static let webSocketDidReceiveMessage = Notification.Name("webSocketDidReceiveMessage")
    static let webSocketDidReceiveData = Notification.Name("webSocketDidReceiveData")
    static let webSocketDidEncounterError = Notification.Name("webSocketDidEncounterError")
    static let audioStreamUrlReceived = Notification.Name("audioStreamUrlReceived")
    static let audioStreamComplete = Notification.Name("audioStreamComplete")
    static let audioStreamError = Notification.Name("audioStreamError")
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
