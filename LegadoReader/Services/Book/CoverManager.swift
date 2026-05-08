import Foundation
import UIKit
import Combine

class CoverManager: ObservableObject {
    static let shared = CoverManager()
    
    @Published var isLoading = false
    @Published var currentCover: UIImage?
    @Published var availableCovers: [CoverOption] = []
    
    private let fileManager = FileManager.default
    private let cacheManager = CacheManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    struct CoverOption: Identifiable {
        let id: String
        let source: CoverSource
        let url: String?
        let image: UIImage?
        
        enum CoverSource: String {
            case original = "原始封面"
            case source = "书源封面"
            case custom = "自定义"
            case generated = "自动生成"
        }
    }
    
    private init() {}
    
    func fetchAvailableCovers(for book: Book) async {
        await MainActor.run {
            isLoading = true
            availableCovers = []
        }
        
        var options: [CoverOption] = []
        
        options.append(CoverOption(
            id: "original",
            source: .original,
            url: book.cover,
            image: nil
        ))
        
        if let sourceCover = await fetchSourceCover(for: book) {
            options.append(CoverOption(
                id: "source",
                source: .source,
                url: sourceCover,
                image: nil
            ))
        }
        
        let generatedCover = generatePlaceholderCover(for: book)
        options.append(CoverOption(
            id: "generated",
            source: .generated,
            url: nil,
            image: generatedCover
        ))
        
        if let customCover = loadCustomCover(for: book.id) {
            options.append(CoverOption(
                id: "custom",
                source: .custom,
                url: nil,
                image: customCover
            ))
        }
        
        await MainActor.run {
            self.availableCovers = options
            self.isLoading = false
        }
    }
    
    private func fetchSourceCover(for book: Book) async -> String? {
        return book.cover
    }
    
    func generatePlaceholderCover(for book: Book) -> UIImage {
        let size = CGSize(width: 200, height: 280)
        
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return UIImage()
        }
        
        let colors = [
            UIColor.systemBlue,
            UIColor.systemPurple,
            UIColor.systemPink,
            UIColor.systemOrange,
            UIColor.systemTeal,
            UIColor.systemIndigo,
            UIColor.systemGreen,
            UIColor.systemRed
        ]
        
        let color = colors[abs(book.name.hashValue) % colors.count]
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                UIColor.white.withAlphaComponent(0.3).cgColor,
                UIColor.clear.cgColor
            ] as CFArray,
            locations: [0, 1]
        )!
        
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: size.width, y: size.height),
            options: []
        )
        
        let title = book.name
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        let titleRect = CGRect(x: 20, y: size.height / 2 - 40, width: size.width - 40, height: 80)
        title.draw(in: titleRect, withAttributes: titleAttributes)
        
        let authorAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9),
            .paragraphStyle: paragraphStyle
        ]
        
        let authorRect = CGRect(x: 20, y: size.height / 2 + 50, width: size.width - 40, height: 30)
        book.author.draw(in: authorRect, withAttributes: authorAttributes)
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    func loadCoverFromURL(_ urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
    
    func loadImageFromData(_ data: Data) -> UIImage? {
        return UIImage(data: data)
    }
    
    func saveCustomCover(for bookId: String, image: UIImage) -> Bool {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let coversDirectory = documentsDirectory.appendingPathComponent("CustomCovers")
        
        try? fileManager.createDirectory(at: coversDirectory, withIntermediateDirectories: true)
        
        let fileName = "\(bookId).jpg"
        let filePath = coversDirectory.appendingPathComponent(fileName)
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return false
        }
        
        do {
            try imageData.write(to: filePath)
            
            let imagePathKey = "CustomCoverPath_\(bookId)"
            UserDefaults.standard.set(filePath.path, forKey: imagePathKey)
            
            return true
        } catch {
            return false
        }
    }
    
    func loadCustomCover(for bookId: String) -> UIImage? {
        let imagePathKey = "CustomCoverPath_\(bookId)"
        
        if let path = UserDefaults.standard.string(forKey: imagePathKey) {
            return UIImage(contentsOfFile: path)
        }
        
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = documentsDirectory
            .appendingPathComponent("CustomCovers")
            .appendingPathComponent("\(bookId).jpg")
        
        if fileManager.fileExists(atPath: filePath.path) {
            UserDefaults.standard.set(filePath.path, forKey: imagePathKey)
            return UIImage(contentsOfFile: filePath.path)
        }
        
        return nil
    }
    
    func deleteCustomCover(for bookId: String) {
        let imagePathKey = "CustomCoverPath_\(bookId)"
        
        if let path = UserDefaults.standard.string(forKey: imagePathKey) {
            try? fileManager.removeItem(atPath: path)
        }
        
        UserDefaults.standard.removeObject(forKey: imagePathKey)
    }
    
    func setCover(for bookId: String, coverURL: String?) {
        let coverURLKey = "BookCoverURL_\(bookId)"
        
        if let url = coverURL {
            UserDefaults.standard.set(url, forKey: coverURLKey)
        } else {
            UserDefaults.standard.removeObject(forKey: coverURLKey)
        }
    }
    
    func getCoverURL(for bookId: String) -> String? {
        let coverURLKey = "BookCoverURL_\(bookId)"
        return UserDefaults.standard.string(forKey: coverURLKey)
    }
    
    func getEffectiveCoverURL(for book: Book) -> String? {
        if let customCover = getCoverURL(for: book.id) {
            return customCover
        }
        
        return book.cover
    }
    
    func fetchCoverImage(for book: Book) async -> UIImage? {
        if let cachedImage = loadCustomCover(for: book.id) {
            return cachedImage
        }
        
        guard let coverURL = book.cover, let url = URL(string: coverURL) else {
            return generatePlaceholderCover(for: book)
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let image = UIImage(data: data) {
                return image
            }
        } catch {
            return generatePlaceholderCover(for: book)
        }
        
        return generatePlaceholderCover(for: book)
    }
    
    func clearCoverCache(for bookId: String) {
        deleteCustomCover(for: bookId)
        setCover(for: bookId, coverURL: nil)
    }
}

extension CoverManager {
    func validateImageURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        let validSchemes = ["http", "https"]
        guard let scheme = url.scheme, validSchemes.contains(scheme.lowercased()) else {
            return false
        }
        
        let validExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp"]
        guard let ext = url.pathExtension.lowercased().components(separatedBy: "?").first,
              validExtensions.contains(ext) else {
            return true
        }
        
        return true
    }
    
    func compressImage(_ image: UIImage, maxSizeKB: Int = 500) -> Data? {
        var compression: CGFloat = 1.0
        var imageData = image.jpegData(compressionQuality: compression)
        
        while let data = imageData, data.count > maxSizeKB * 1024, compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }
        
        return imageData
    }
    
    func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
}
