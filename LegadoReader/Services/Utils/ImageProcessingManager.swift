import UIKit
import SwiftUI
import Combine

class ImageProcessingManager {
    static let shared = ImageProcessingManager()
    
    private let processingQueue = DispatchQueue(label: "com.legadoreader.imageprocessing", qos: .userInitiated, attributes: .concurrent)
    
    private var cachedImages: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024
        return cache
    }()
    
    private var tintedImages: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 50
        return cache
    }()
    
    private var cornerRadiusCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 50
        return cache
    }()
    
    private init() {}
    
    enum ImageError: Error {
        case invalidImage
        case processingFailed
        case cacheFailed
    }
    
    struct ProcessingOptions {
        var cornerRadius: CGFloat = 0
        var targetSize: CGSize?
        var tintColor: UIColor?
        var shadowRadius: CGFloat = 0
        var shadowOpacity: Float = 0
        var shadowOffset: CGSize = .zero
        var shouldCache: Bool = true
        
        init() {}
    }
    
    func processImage(_ image: UIImage, options: ProcessingOptions, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = generateCacheKey(for: image, options: options)
        
        if options.shouldCache, let cached = cachedImages.object(forKey: cacheKey as NSString) {
            completion(cached)
            return
        }
        
        processingQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            var resultImage = image
            
            if let targetSize = options.targetSize {
                resultImage = self.resizeImage(resultImage, to: targetSize)
            }
            
            if options.cornerRadius > 0 {
                resultImage = self.applyCornerRadius(to: resultImage, radius: options.cornerRadius)
            }
            
            if let tintColor = options.tintColor {
                resultImage = self.applyTintColor(to: resultImage, color: tintColor)
            }
            
            if options.shadowRadius > 0 {
                resultImage = self.applyShadow(to: resultImage, radius: options.shadowRadius, opacity: options.shadowOpacity, offset: options.shadowOffset)
            }
            
            if options.shouldCache {
                self.cachedImages.setObject(resultImage, forKey: cacheKey as NSString, cost: Int(resultImage.size.width * resultImage.size.height * 4))
            }
            
            DispatchQueue.main.async {
                completion(resultImage)
            }
        }
    }
    
    func applyTintColor(_ image: UIImage, color: UIColor) -> UIImage {
        let cacheKey = "tint_\(image.hashValue)_\(color.hexString ?? "")"
        
        if let cached = tintedImages.object(forKey: cacheKey as NSString) {
            return cached
        }
        
        guard let cgImage = image.cgImage else { return image }
        
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        
        let rect = CGRect(origin: .zero, size: size)
        
        context.clip(to: rect, mask: cgImage)
        
        color.setFill()
        rect.fill()
        
        color.setStroke()
        context.setLineWidth(0)
        context.addPath(context.path ?? CGPath(rect: rect, transform: nil))
        context.strokePath()
        
        guard let tintedImage = UIGraphicsGetImageFromCurrentImageContext() else { return image }
        
        tintedImages.setObject(tintedImage, forKey: cacheKey as NSString)
        
        return tintedImage
    }
    
    func applyCornerRadius(to image: UIImage, radius: CGFloat) -> UIImage {
        let cacheKey = "corner_\(image.hashValue)_\(radius)"
        
        if let cached = cornerRadiusCache.object(forKey: cacheKey as NSString) {
            return cached
        }
        
        guard let cgImage = image.cgImage else { return image }
        
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsBeginImageContextWithOptions(size, false, image.scale) != nil else { return image }
        
        let rect = CGRect(origin: .zero, size: size)
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: .allCorners, cornerRadii: CGSize(width: radius, height: radius))
        
        context.addPath(path.cgPath)
        context.clip()
        
        image.draw(in: rect)
        
        guard let roundedImage = UIGraphicsGetImageFromCurrentImageContext() else { return image }
        
        cornerRadiusCache.setObject(roundedImage, forKey: cacheKey as NSString)
        
        return roundedImage
    }
    
    func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        let widthRatio = targetSize.width / image.size.width
        let heightRatio = targetSize.height / image.size.height
        
        let scaleFactor = min(widthRatio, heightRatio)
        
        let scaledSize = CGSize(
            width: image.size.width * scaleFactor,
            height: image.size.height * scaleFactor
        )
        
        UIGraphicsBeginImageContextWithOptions(scaledSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: scaledSize))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    func applyShadow(to image: UIImage, radius: CGFloat, opacity: Float, offset: CGSize) -> UIImage {
        let padding = radius * 2
        let size = CGSize(
            width: image.size.width + padding * 2,
            height: image.size.height + padding * 2
        )
        
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        
        context.setShadow(offset: offset, blur: radius, color: UIColor.black.withAlphaComponent(CGFloat(opacity)).cgColor)
        
        image.draw(at: CGPoint(x: padding, y: padding))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    func generatePlaceholder(size: CGSize, color: UIColor = .systemGray5, cornerRadius: CGFloat = 0) -> UIImage {
        let cacheKey = "placeholder_\(Int(size.width))x\(Int(size.height))_\(color.hexString ?? "")_\(cornerRadius)"
        
        if let cached = cachedImages.object(forKey: cacheKey as NSString) {
            return cached
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        let rect = CGRect(origin: .zero, size: size)
        
        if cornerRadius > 0 {
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            color.setFill()
            path.fill()
        } else {
            color.setFill()
            rect.fill()
        }
        
        guard let placeholder = UIGraphicsGetImageFromCurrentImageContext() else {
            return UIImage()
        }
        
        cachedImages.setObject(placeholder, forKey: cacheKey as NSString)
        
        return placeholder
    }
    
    func clearCache() {
        cachedImages.removeAllObjects()
        tintedImages.removeAllObjects()
        cornerRadiusCache.removeAllObjects()
    }
    
    private func generateCacheKey(for image: UIImage, options: ProcessingOptions) -> String {
        var key = "\(image.hashValue)"
        if let size = options.targetSize {
            key += "_size_\(Int(size.width))x\(Int(size.height))"
        }
        if options.cornerRadius > 0 {
            key += "_corner_\(options.cornerRadius)"
        }
        if let tintColor = options.tintColor {
            key += "_tint_\(tintColor.hashValue)"
        }
        if options.shadowRadius > 0 {
            key += "_shadow_\(options.shadowRadius)"
        }
        return key
    }
}

class ImageLoader: ObservableObject {
    static let shared = ImageLoader()
    
    @Published var loadedImages: [String: UIImage] = [:]
    
    private var loadingTasks: [String: Task<Void, Never>] = [:]
    private let processingManager = ImageProcessingManager.shared
    
    private init() {}
    
    func loadImage(from urlString: String, placeholder: UIImage? = nil, completion: @escaping (UIImage?) -> Void) {
        if let existingImage = loadedImages[urlString] {
            completion(existingImage)
            return
        }
        
        guard let url = URL(string: urlString) else {
            completion(placeholder)
            return
        }
        
        if let existingTask = loadingTasks[urlString] {
            existingTask.cancel()
        }
        
        let task = Task { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                guard !Task.isCancelled, let self = self else { return }
                
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.loadedImages[urlString] = image
                        completion(image)
                    }
                } else {
                    await MainActor.run {
                        completion(placeholder)
                    }
                }
            } catch {
                await MainActor.run {
                    completion(placeholder)
                }
            }
            
            await MainActor.run {
                self.loadingTasks.removeValue(forKey: urlString)
            }
        }
        
        loadingTasks[urlString] = task
    }
    
    func cancelLoad(for urlString: String) {
        loadingTasks[urlString]?.cancel()
        loadingTasks.removeValue(forKey: urlString)
    }
    
    func clearCache() {
        loadedImages.removeAll()
        processingManager.clearCache()
    }
}

extension UIColor {
    var hexString: String? {
        guard let components = cgColor.components, components.count >= 3 else { return nil }
        
        let r = Float(components[0])
        let g = Float(components.count >= 3 ? components[1] : components[0])
        let b = Float(components.count >= 3 ? components[2] : components[0])
        
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}
