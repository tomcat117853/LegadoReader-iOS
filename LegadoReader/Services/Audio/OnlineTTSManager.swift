import Foundation
import AVFoundation
import Combine

class OnlineTTSManager: NSObject, ObservableObject {
    static let shared = OnlineTTSManager()
    
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var currentText = ""
    @Published var progress: Double = 0
    @Published var selectedVoice: OnlineVoice
    @Published var availableVoices: [OnlineVoice] = []
    @Published var error: String?
    @Published var speechStyle: SpeechStyle = .general
    
    private var audioPlayer: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    enum SpeechStyle: String, CaseIterable, Identifiable {
        case general = "general"
        case cheerful = "cheerful"
        case sad = "sad"
        case angry = "angry"
        case fearful = "fearful"
        case excited = "excited"
        case friendly = "friendly"
        case hopeful = "hopeful"
        case whispering = "whispering"
        case customerservice = "customerservice"
        case narration = "narration"
        case newscast = "newscast"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .general: return "一般"
            case .cheerful: return "欢快"
            case .sad: return "悲伤"
            case .angry: return "愤怒"
            case .fearful: return "恐惧"
            case .excited: return "兴奋"
            case .friendly: return "友好"
            case .hopeful: return "希望"
            case .whispering: return "低语"
            case .customerservice: return "客服"
            case .narration: return "叙述"
            case .newscast: return "新闻"
            }
        }
    }
    
    struct OnlineVoice: Identifiable, Codable {
        let id: String
        let name: String
        let language: String
        let region: String
        let gender: Gender
        let service: TTSService
        let isNeural: Bool
        let isPremium: Bool
        let supportsStyles: Bool
        
        enum Gender: String, Codable {
            case female = "Female"
            case male = "Male"
        }
        
        enum TTSService: String, Codable {
            case azure = "Azure"
            case edge = "Edge"
            case google = "Google"
            case free = "Free"
        }
    }
    
    struct TTSConfig: Codable {
        var azureApiKey: String
        var azureRegion: String
        var edgeVoices: [String: String]
        
        static var `default`: TTSConfig {
            TTSConfig(
                azureApiKey: "",
                azureRegion: "eastasia",
                edgeVoices: [:]
            )
        }
    }
    
    override init() {
        selectedVoice = OnlineVoice(
            id: "zh-CN-XiaoxiaoNeural",
            name: "晓晓",
            language: "zh-CN",
            region: "eastasia",
            gender: .female,
            service: .azure,
            isNeural: true,
            isPremium: false,
            supportsStyles: true
        )
        super.init()
        loadVoices()
        loadConfig()
    }
    
    private func loadVoices() {
        availableVoices = [
            OnlineVoice(
                id: "zh-CN-XiaoxiaoNeural",
                name: "晓晓",
                language: "zh-CN",
                region: "eastasia",
                gender: .female,
                service: .azure,
                isNeural: true,
                isPremium: false,
                supportsStyles: true
            ),
            OnlineVoice(
                id: "zh-CN-YunxiNeural",
                name: "云希",
                language: "zh-CN",
                region: "eastasia",
                gender: .male,
                service: .azure,
                isNeural: true,
                isPremium: true,
                supportsStyles: true
            ),
            OnlineVoice(
                id: "zh-CN-XiaoyiNeural",
                name: "小艺",
                language: "zh-CN",
                region: "eastasia",
                gender: .female,
                service: .azure,
                isNeural: true,
                isPremium: false,
                supportsStyles: true
            ),
            OnlineVoice(
                id: "zh-CN-YunyangNeural",
                name: "云扬",
                language: "zh-CN",
                region: "eastasia",
                gender: .male,
                service: .azure,
                isNeural: true,
                isPremium: true,
                supportsStyles: true
            ),
            OnlineVoice(
                id: "zh-CN-XiaochenNeural",
                name: "晓辰",
                language: "zh-CN",
                region: "eastasia",
                gender: .female,
                service: .azure,
                isNeural: true,
                isPremium: true,
                supportsStyles: true
            ),
            OnlineVoice(
                id: "zh-CN-YunfengNeural",
                name: "云枫",
                language: "zh-CN",
                region: "eastasia",
                gender: .male,
                service: .azure,
                isNeural: true,
                isPremium: true,
                supportsStyles: true
            ),
            OnlineVoice(
                id: "zh-HK-HiuGaaiNeural",
                name: "凱萊",
                language: "zh-HK",
                region: "eastasia",
                gender: .female,
                service: .azure,
                isNeural: true,
                isPremium: false,
                supportsStyles: true
            ),
            OnlineVoice(
                id: "zh-TW-HsiaoYuNeural",
                name: "曉雨",
                language: "zh-TW",
                region: "eastasia",
                gender: .female,
                service: .azure,
                isNeural: true,
                isPremium: false,
                supportsStyles: true
            ),
            OnlineVoice(
                id: "en-US-JennyNeural",
                name: "Jenny",
                language: "en-US",
                region: "eastasia",
                gender: .female,
                service: .azure,
                isNeural: true,
                isPremium: false,
                supportsStyles: true
            ),
            OnlineVoice(
                id: "en-US-GuyNeural",
                name: "Guy",
                language: "en-US",
                region: "eastasia",
                gender: .male,
                service: .azure,
                isNeural: true,
                isPremium: false,
                supportsStyles: true
            )
        ]
    }
    
    private func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: "OnlineTTSConfig"),
           let config = try? JSONDecoder().decode(TTSConfig.self, from: data) {
            // Load config if needed
        }
    }
    
    func saveConfig(_ config: TTSConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "OnlineTTSConfig")
        }
    }
    
    func selectVoice(_ voice: OnlineVoice) {
        selectedVoice = voice
        speechStyle = voice.supportsStyles ? .general : .general
    }
    
    func speak(text: String) {
        stop()
        
        guard !text.isEmpty else {
            error = "没有可朗读的文本"
            return
        }
        
        isLoading = true
        currentText = text
        progress = 0
        
        synthesizeAndPlay(text: text)
    }
    
    private func synthesizeAndPlay(text: String) {
        let serviceType = getServiceType()
        
        switch serviceType {
        case .edge:
            synthesizeWithEdge(text: text)
        case .azure:
            synthesizeWithAzure(text: text)
        case .free:
            synthesizeWithFreeService(text: text)
        }
    }
    
    private func getServiceType() -> OnlineVoice.TTSService {
        return .edge
    }
    
    private func synthesizeWithEdge(text: String) {
        let cleanedText = text.replacingOccurrences(of: "\"", with: "'")
        let encodedText = cleanedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanedText
        
        let style = selectedVoice.supportsStyles && speechStyle != .general ? 
            "&style=\(speechStyle.rawValue)" : ""
        
        let urlString = "https://voice.xunfei.com.cn/ttsapi/v1/tts_prod?appid=596&text=\(encodedText)&speaker=0&volume=50&speed=50&pitch=50&aue=3\(style)"
        
        guard let url = URL(string: urlString) else {
            synthesizeWithFreeService(text: text)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    self?.synthesizeWithFreeService(text: text)
                    return
                }
                
                guard let data = data, !data.isEmpty else {
                    self?.error = "未获取到音频数据"
                    self?.synthesizeWithFreeService(text: text)
                    return
                }
                
                self?.playAudio(data: data)
            }
        }.resume()
    }
    
    private func synthesizeWithAzure(text: String) {
        let configData = UserDefaults.standard.data(forKey: "OnlineTTSConfig")
        guard let config = try? JSONDecoder().decode(TTSConfig.self, from: configData ?? Data()),
              !config.azureApiKey.isEmpty else {
            synthesizeWithFreeService(text: text)
            return
        }
        
        let endpoint = "https://\(config.azureRegion).tts.speech.microsoft.com/cognitiveservices/v1"
        let url = URL(string: endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(getAzureToken(apiKey: config.azureApiKey))", forHTTPHeaderField: "Authorization")
        request.setValue("Microsoft Speech Studio", forHTTPHeaderField: "X-Microsoft-OutputFormat")
        
        var ssml = """
        <speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='\(selectedVoice.language)'>
            <voice name='\(selectedVoice.id)'>
        """
        
        if selectedVoice.supportsStyles && speechStyle != .general {
            ssml += """
                <mstts:express-as style='\(speechStyle.rawValue)'>
                    \(text)
                </mstts:express-as>
            """
        } else {
            ssml += text
        }
        
        ssml += """
            </voice>
        </speak>
        """
        
        request.httpBody = ssml.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    self?.synthesizeWithFreeService(text: text)
                    return
                }
                
                guard let data = data, !data.isEmpty else {
                    self?.error = "未获取到音频数据"
                    self?.synthesizeWithFreeService(text: text)
                    return
                }
                
                self?.playAudio(data: data)
            }
        }.resume()
    }
    
    private func getAzureToken(apiKey: String) -> String {
        return apiKey
    }
    
    private func synthesizeWithFreeService(text: String) {
        let cleanedText = text.replacingOccurrences(of: "\"", with: "'")
        let encodedText = cleanedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanedText
        
        let voiceMap: [String: String] = [
            "zh-CN-XiaoxiaoNeural": "zh-CN",
            "zh-CN-YunxiNeural": "zh-CN",
            "zh-CN-XiaoyiNeural": "zh-CN",
            "zh-CN-YunyangNeural": "zh-CN"
        ]
        
        let langCode = voiceMap[selectedVoice.id] ?? "zh-CN"
        
        let urlString = "https://tts.xunfei.com.cn/tts?text=\(encodedText)&lang=\(langCode)&source=web"
        
        guard let url = URL(string: urlString) else {
            useLocalTTS(text: text)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 15_4 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    self?.useLocalTTS(text: text)
                    return
                }
                
                guard let data = data, !data.isEmpty else {
                    self?.useLocalTTS(text: text)
                    return
                }
                
                self?.playAudio(data: data)
            }
        }.resume()
    }
    
    private func useLocalTTS(text: String) {
        AudioBookManager.shared.speak(text: text)
    }
    
    private func playAudio(data: Data) {
        do {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp3")
            try data.write(to: tempURL)
            
            playerItem = AVPlayerItem(url: tempURL)
            audioPlayer = AVPlayer(playerItem: playerItem)
            
            setupTimeObserver()
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerDidFinish),
                name: .AVPlayerItemDidPlayToEndTime,
                object: playerItem
            )
            
            audioPlayer?.play()
            isPlaying = true
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            useLocalTTS(text: currentText)
        }
    }
    
    private func setupTimeObserver() {
        guard let player = audioPlayer, let item = playerItem else { return }
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self,
                  let duration = item.asset.duration.seconds.isNaN ? nil : item.asset.duration.seconds as Double?,
                  duration > 0 else { return }
            
            let currentTime = time.seconds
            self.progress = currentTime / duration
        }
    }
    
    @objc private func playerDidFinish() {
        isPlaying = false
        progress = 1.0
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    func resume() {
        audioPlayer?.play()
        isPlaying = true
    }
    
    func stop() {
        audioPlayer?.pause()
        audioPlayer = nil
        playerItem = nil
        isPlaying = false
        progress = 0
        currentText = ""
        
        if let observer = timeObserver {
            audioPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    func seek(to progress: Double) {
        guard let item = playerItem,
              let duration = item.asset.duration.seconds.isNaN ? nil : item.asset.duration.seconds as Double? else { return }
        
        let time = CMTime(seconds: duration * progress, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        audioPlayer?.seek(to: time)
        self.progress = progress
    }
    
    func getAvailableStyles() -> [SpeechStyle] {
        if selectedVoice.supportsStyles {
            return SpeechStyle.allCases
        }
        return [.general]
    }
}

extension OnlineTTSManager {
    func getVoicesByLanguage(_ language: String) -> [OnlineVoice] {
        return availableVoices.filter { $0.language.hasPrefix(language) }
    }
    
    func getVoicesByGender(_ gender: OnlineVoice.Gender) -> [OnlineVoice] {
        return availableVoices.filter { $0.gender == gender }
    }
    
    func getNeuralVoices() -> [OnlineVoice] {
        return availableVoices.filter { $0.isNeural }
    }
    
    func getChineseVoices() -> [OnlineVoice] {
        return availableVoices.filter { $0.language.hasPrefix("zh") }
    }
}

class AzureTokenManager {
    static let shared = AzureTokenManager()
    
    private var cachedToken: String?
    private var tokenExpiration: Date?
    
    func getToken(apiKey: String, region: String, completion: @escaping (String?) -> Void) {
        if let cached = cachedToken,
           let expiration = tokenExpiration,
           Date() < expiration {
            completion(cached)
            return
        }
        
        let url = URL(string: "https://\(region).api.cognitive.microsoft.com/sts/v1.0/issueToken")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data,
                  let token = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            
            self?.cachedToken = token
            self?.tokenExpiration = Date().addingTimeInterval(540)
            
            DispatchQueue.main.async {
                completion(token)
            }
        }.resume()
    }
}
