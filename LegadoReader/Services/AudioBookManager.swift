import Foundation
import AVFoundation
import Combine

class AudioBookManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = AudioBookManager()
    
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var isPrepared = false
    @Published var currentText = ""
    @Published var currentChapterTitle = ""
    @Published var progress: Double = 0
    @Published var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
    @Published var volume: Float = 1.0
    @Published var selectedVoice: String = "com.apple.voice.compact.zh-CN"
    @Published var error: String?
    
    @Published var chapters: [Chapter] = []
    @Published var currentChapterIndex = 0
    @Published var currentBookId: String?
    @Published var currentBookName: String = ""
    
    private var synthesizer: AVSpeechSynthesizer!
    private var currentUtterance: AVSpeechUtterance?
    private var pendingText: String = ""
    private var startTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    struct VoiceOption: Identifiable {
        let id: String
        let name: String
        let language: String
        let isPremium: Bool
    }
    
    override init() {
        super.init()
        setupAudioSession()
        setupSynthesizer()
        loadSettings()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
            self.error = error.localizedDescription
        }
    }
    
    private func setupSynthesizer() {
        synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        speechRate = defaults.float(forKey: "AudioBook_speechRate")
        if speechRate == 0 {
            speechRate = AVSpeechUtteranceDefaultSpeechRate
        }
        
        volume = defaults.float(forKey: "AudioBook_volume")
        if volume == 0 {
            volume = 1.0
        }
        
        if let voice = defaults.string(forKey: "AudioBook_voice") {
            selectedVoice = voice
        }
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(speechRate, forKey: "AudioBook_speechRate")
        defaults.set(volume, forKey: "AudioBook_volume")
        defaults.set(selectedVoice, forKey: "AudioBook_voice")
    }
    
    func getAvailableVoices() -> [VoiceOption] {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        var options: [VoiceOption] = []
        
        for voice in voices {
            if voice.language.hasPrefix("zh") || voice.language.hasPrefix("en") {
                options.append(VoiceOption(
                    id: voice.identifier,
                    name: voice.name,
                    language: voice.language,
                    isPremium: voice.quality == .enhanced
                ))
            }
        }
        
        return options.sorted { ($0.isPremium ? 0 : 1) < ($1.isPremium ? 0 : 1) }
    }
    
    func prepareForBook(bookId: String, bookName: String, chapters: [Chapter], startChapter: Int = 0) {
        currentBookId = bookId
        currentBookName = bookName
        self.chapters = chapters
        currentChapterIndex = startChapter
        
        if !chapters.isEmpty && currentChapterIndex < chapters.count {
            loadChapter(at: currentChapterIndex)
        }
    }
    
    func loadChapter(at index: Int) {
        guard index >= 0 && index < chapters.count else { return }
        
        let chapter = chapters[index]
        currentChapterTitle = chapter.title
        
        if let content = chapter.content {
            pendingText = content
            currentText = content
            isPrepared = true
            progress = 0
        } else {
            currentText = ""
            isPrepared = false
        }
    }
    
    func play() {
        guard isPrepared && !pendingText.isEmpty else {
            error = "没有可播放的内容"
            return
        }
        
        if isPaused {
            synthesizer.continueSpeaking()
            isPaused = false
            isPlaying = true
            startTime = Date()
        } else {
            speak(text: pendingText)
            isPlaying = true
            startTime = Date()
        }
    }
    
    private func speak(text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.volume = volume
        utterance.pitchMultiplier = 1.0
        
        if let voice = AVSpeechSynthesisVoice(identifier: selectedVoice) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        }
        
        currentUtterance = utterance
        synthesizer.speak(utterance)
    }
    
    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        isPaused = true
        isPlaying = false
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        isPrepared = false
        progress = 0
        startTime = nil
    }
    
    func nextChapter() {
        stop()
        if currentChapterIndex < chapters.count - 1 {
            currentChapterIndex += 1
            loadChapter(at: currentChapterIndex)
            if isPrepared {
                play()
            }
        }
    }
    
    func previousChapter() {
        stop()
        if currentChapterIndex > 0 {
            currentChapterIndex -= 1
            loadChapter(at: currentChapterIndex)
            if isPrepared {
                play()
            }
        }
    }
    
    func setChapter(_ index: Int) {
        stop()
        currentChapterIndex = index
        loadChapter(at: index)
    }
    
    func setSpeed(_ rate: Float) {
        speechRate = max(AVSpeechUtteranceMinimumSpeechRate, min(rate, AVSpeechUtteranceMaximumSpeechRate))
        saveSettings()
    }
    
    func setVolume(_ vol: Float) {
        volume = max(0, min(vol, 1))
        saveSettings()
    }
    
    func setVoice(_ voiceId: String) {
        selectedVoice = voiceId
        saveSettings()
    }
    
    func getSpeedOptions() -> [(String, Float)] {
        return [
            ("0.5x", AVSpeechUtteranceMinimumSpeechRate),
            ("0.75x", AVSpeechUtteranceMinimumSpeechRate * 1.5),
            ("1.0x", AVSpeechUtteranceDefaultSpeechRate),
            ("1.25x", AVSpeechUtteranceDefaultSpeechRate * 1.25),
            ("1.5x", AVSpeechUtteranceDefaultSpeechRate * 1.5),
            ("2.0x", AVSpeechUtteranceMaximumSpeechRate)
        ]
    }
    
    func getElapsedTime() -> TimeInterval {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }
    
    func estimateRemainingTime() -> TimeInterval {
        guard !currentText.isEmpty && progress > 0 else {
            return 0
        }
        
        let elapsed = getElapsedTime()
        let remaining = (1.0 - progress) * Double(currentText.count)
        let totalEstimate = elapsed / progress
        return totalEstimate - elapsed
    }
    
    func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    func formatSpeed(_ rate: Float) -> String {
        if rate <= AVSpeechUtteranceMinimumSpeechRate {
            return "0.5x"
        } else if rate >= AVSpeechUtteranceMaximumSpeechRate {
            return "2.0x"
        } else if rate < AVSpeechUtteranceDefaultSpeechRate {
            let ratio = (rate - AVSpeechUtteranceMinimumSpeechRate) / (AVSpeechUtteranceDefaultSpeechRate - AVSpeechUtteranceMinimumSpeechRate)
            return String(format: "%.2fx", 0.5 + ratio * 0.5)
        } else {
            let ratio = (rate - AVSpeechUtteranceDefaultSpeechRate) / (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceDefaultSpeechRate)
            return String(format: "%.2fx", 1.0 + ratio)
        }
    }
    
    func getCurrentProgress() -> (chapter: Int, total: Int, progress: Double) {
        return (currentChapterIndex + 1, chapters.count, progress)
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = true
            self.isPaused = false
            self.startTime = Date()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isPaused = false
            
            if self.currentChapterIndex < self.chapters.count - 1 {
                self.nextChapter()
            } else {
                NotificationCenter.default.post(name: .audioBookDidFinish, object: nil)
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPaused = true
            self.isPlaying = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPaused = false
            self.isPlaying = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            let totalLength = utterance.speechString.count
            if totalLength > 0 {
                self.progress = Double(characterRange.location + characterRange.length) / Double(totalLength)
            }
        }
    }
}

extension Notification.Name {
    static let audioBookDidFinish = Notification.Name("audioBookDidFinish")
}
