import SwiftUI
import UIKit

struct CardView<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 12
    var shadowRadius: CGFloat = 5
    var shadowOpacity: Float = 0.1
    var shadowOffset: CGSize = CGSize(width: 0, height: 2)
    var padding: CGFloat = 16
    var useSystemShadow: Bool = true
    
    init(
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 5,
        shadowOpacity: Float = 0.1,
        shadowOffset: CGSize = CGSize(width: 0, height: 2),
        padding: CGFloat = 16,
        useSystemShadow: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.shadowOpacity = shadowOpacity
        self.shadowOffset = shadowOffset
        self.padding = padding
        self.useSystemShadow = useSystemShadow
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(Color(.systemBackground))
            .cornerRadius(cornerRadius)
            .shadow(
                color: Color.black.opacity(CGFloat(shadowOpacity)),
                radius: useSystemShadow ? shadowRadius : 0,
                x: shadowOffset.width,
                y: shadowOffset.height
            )
    }
}

struct OptimizedCardView<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 12
    var shadowRadius: CGFloat = 5
    var shadowOpacity: Float = 0.1
    var shadowOffset: CGSize = CGSize(width: 0, height: 2)
    var padding: CGFloat = 16
    
    init(
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 5,
        shadowOpacity: Float = 0.1,
        shadowOffset: CGSize = CGSize(width: 0, height: 2),
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.shadowOpacity = shadowOpacity
        self.shadowOffset = shadowOffset
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(color: .clear, radius: 0)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(CGFloat(shadowOpacity)))
                    .blur(radius: shadowRadius)
                    .offset(y: shadowOffset.height)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct BookCardView: View {
    let book: Book
    var showProgress: Bool = true
    var cornerRadius: CGFloat = 12
    var onTap: (() -> Void)?
    var onLongPress: (() -> Void)?
    
    @StateObject private var imageLoader = ImageLoader.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BookCoverImage(
                coverUrl: book.coverUrl,
                bookName: book.name,
                cornerRadius: 8
            )
            .frame(height: 160)
            .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                if let author = book.author, !author.isEmpty {
                    Text(author)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if showProgress && book.durProgress > 0 {
                    ProgressView(value: book.durProgress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                        .scaleEffect(y: 0.5)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(cornerRadius)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
        .onTapGesture {
            onTap?()
        }
        .onLongPressGesture {
            onLongPress?()
        }
    }
}

struct BookCoverImage: View {
    let coverUrl: String?
    let bookName: String
    var cornerRadius: CGFloat = 8
    var placeholderColor: Color = .gray
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    PlaceholderCoverView(name: bookName, cornerRadius: cornerRadius)
                }
                
                if isLoading && loadedImage == nil {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
        }
        .cornerRadius(cornerRadius)
        .onAppear {
            loadImage()
        }
        .onChange(of: coverUrl) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = coverUrl, !url.isEmpty else { return }
        
        isLoading = true
        
        imageLoader.loadImage(from: url) { image in
            isLoading = false
            if let image = image {
                let options = ImageProcessingManager.ProcessingOptions()
                ImageProcessingManager.shared.processImage(image, options: options) { processed in
                    loadedImage = processed
                }
            }
        }
    }
}

struct PlaceholderCoverView: View {
    let name: String
    var cornerRadius: CGFloat = 8
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }
}

struct CachedAsyncImage: View {
    let url: String?
    let placeholder: Image
    var cornerRadius: CGFloat = 0
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    placeholder
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                
                if isLoading && loadedImage == nil {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
        }
        .cornerRadius(cornerRadius)
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let urlString = url, !urlString.isEmpty else { return }
        
        isLoading = true
        
        ImageLoader.shared.loadImage(from: urlString) { image in
            isLoading = false
            loadedImage = image
        }
    }
}

struct TintedImageView: View {
    let systemName: String
    var tintColor: Color = .blue
    var size: CGFloat = 24
    
    @State private var tintedImage: UIImage?
    
    var body: some View {
        Group {
            if let image = tintedImage {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.original)
            } else {
                Image(systemName: systemName)
                    .foregroundColor(tintColor)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            applyTint()
        }
    }
    
    private func applyTint() {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .regular)
        if let image = UIImage(systemName: systemName, withConfiguration: config)?
            .withTintColor(UIColor(tintColor), renderingMode: .alwaysOriginal) {
            tintedImage = image
        }
    }
}

struct ShadowedImage: View {
    let image: UIImage?
    var cornerRadius: CGFloat = 8
    var shadowRadius: CGFloat = 4
    var shadowOpacity: Float = 0.2
    var shadowOffset: CGSize = CGSize(width: 0, height: 2)
    var size: CGSize = CGSize(width: 100, height: 150)
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                PlaceholderImage()
            }
        }
        .frame(width: size.width, height: size.height)
        .cornerRadius(cornerRadius)
        .shadow(
            color: .black.opacity(CGFloat(shadowOpacity)),
            radius: shadowRadius,
            x: shadowOffset.width,
            y: shadowOffset.height
        )
        .clipped()
    }
}

struct PlaceholderImage: View {
    var body: some View {
        ZStack {
            Color.gray.opacity(0.3)
            Image(systemName: "photo")
                .font(.title)
                .foregroundColor(.gray)
        }
    }
}

struct CardGrid<Item: Identifiable, ItemView: View>: View {
    let items: [Item]
    let columns: Int
    let spacing: CGFloat
    let itemContent: (Item) -> ItemView
    
    init(
        items: [Item],
        columns: Int = 2,
        spacing: CGFloat = 16,
        @ViewBuilder itemContent: @escaping (Item) -> ItemView
    ) {
        self.items = items
        self.columns = columns
        self.spacing = spacing
        self.itemContent = itemContent
    }
    
    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
            spacing: spacing
        ) {
            ForEach(items) { item in
                itemContent(item)
            }
        }
    }
}

struct LazyCardScrollView<Item: Identifiable, ItemView: View>: View {
    let items: [Item]
    let itemHeight: CGFloat
    let itemContent: (Item) -> ItemView
    var showsIndicators: Bool = true
    
    init(
        items: [Item],
        itemHeight: CGFloat = 180,
        showsIndicators: Bool = true,
        @ViewBuilder itemContent: @escaping (Item) -> ItemView
    ) {
        self.items = items
        self.itemHeight = itemHeight
        self.showsIndicators = showsIndicators
        self.itemContent = itemContent
    }
    
    var body: some View {
        ScrollView(showsIndicators: showsIndicators) {
            LazyVStack(spacing: 16) {
                ForEach(items) { item in
                    itemContent(item)
                        .frame(height: itemHeight)
                }
            }
            .padding()
        }
    }
}
