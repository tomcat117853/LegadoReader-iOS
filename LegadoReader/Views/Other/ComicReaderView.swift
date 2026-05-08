import SwiftUI
import UIKit

struct ComicReaderView: View {
    @StateObject private var comicManager = ComicParserManager.shared
    @StateObject private var settings = ComicReadingSettings.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var showingSettings = false
    @State private var showingPageSlider = false
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var magnifierPosition: CGPoint?
    @State private var showingMagnifier = false
    
    let comicBook: ComicParserManager.ComicBook
    
    var body: some View {
        ZStack {
            settings.backgroundColor.color
                .ignoresSafeArea()
            
            if comicManager.isLoading {
                loadingView
            } else {
                comicContentView
            }
            
            if showingPageSlider || settings.showPageSlider {
                pageSliderOverlay
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .sheet(isPresented: $showingSettings) {
            ComicSettingsView()
        }
        .onAppear {
            loadComic()
        }
        .onDisappear {
            comicManager.closeComic()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("正在加载漫画...")
                .foregroundColor(.white)
            Text("\(Int(comicManager.loadingProgress * 100))%")
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    @ViewBuilder
    private var comicContentView: some View {
        switch settings.readingMode {
        case .rightToLeft, .leftToRight:
            horizontalPageView
        case .vertical:
            verticalScrollView
        case .webtoon:
            webtoonView
        case .automatic:
            horizontalPageView
        }
    }
    
    private var horizontalPageView: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = comicManager.getPage(at: comicManager.currentPage) {
                    ZoomableImageView(
                        image: image,
                        scale: $currentScale,
                        lastScale: $lastScale,
                        offset: $offset,
                        lastOffset: $lastOffset,
                        magnifierPosition: $magnifierPosition,
                        showMagnifier: showingMagnifier,
                        enableMagnifier: settings.magnifierEnabled,
                        magnifierSize: settings.magnifierSize
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .onTapGesture(count: 2) {
                        withAnimation {
                            if currentScale > 1.0 {
                                currentScale = 1.0
                                offset = .zero
                            } else {
                                currentScale = 2.0
                            }
                        }
                    }
                    .onTapGesture { location in
                        handleTap(at: location, in: geometry.size)
                    }
                }
            }
        }
    }
    
    private var verticalScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(0..<comicManager.pageCount, id: \.self) { index in
                        if let image = comicManager.getPage(at: index) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .id(index)
                        }
                    }
                }
            }
        }
    }
    
    private var webtoonView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    ForEach(0..<comicManager.pageCount, id: \.self) { index in
                        if let image = comicManager.getPage(at: index) {
                            Image(uiImage: image)
                                .resizable()
                                .frame(maxWidth: UIScreen.main.bounds.width)
                                .id(index)
                        }
                    }
                }
            }
        }
    }
    
    private var pageSliderOverlay: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 8) {
                HStack {
                    Text("\(comicManager.currentPage + 1) / \(comicManager.pageCount)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(16)
                }
                
                if settings.showPageSlider {
                    Slider(
                        value: Binding(
                            get: { Double(comicManager.currentPage) },
                            set: { comicManager.goToPage(Int($0)) }
                        ),
                        in: 0...Double(max(0, comicManager.pageCount - 1)),
                        step: 1
                    )
                    .padding(.horizontal)
                    .tint(.white)
                }
            }
            .padding(.bottom, 30)
        }
    }
    
    private func handleTap(at location: CGPoint, in size: CGSize) {
        let leftZone = size.width / 3
        let rightZone = size.width * 2 / 3
        
        if settings.readingMode == .rightToLeft {
            if location.x < leftZone {
                comicManager.nextPage()
            } else if location.x > rightZone {
                comicManager.previousPage()
            } else {
                withAnimation {
                    showingPageSlider.toggle()
                }
            }
        } else {
            if location.x < leftZone {
                comicManager.previousPage()
            } else if location.x > rightZone {
                comicManager.nextPage()
            } else {
                withAnimation {
                    showingPageSlider.toggle()
                }
            }
        }
    }
    
    private func loadComic() {
        let url = URL(fileURLWithPath: comicBook.sourcePath)
        Task {
            do {
                _ = try await comicManager.parseComic(at: url)
            } catch {
                print("Failed to load comic: \(error)")
            }
        }
    }
}

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize
    @Binding var magnifierPosition: CGPoint?
    var showMagnifier: Bool
    var enableMagnifier: Bool
    var magnifierSize: ComicReadingSettings.MagnifierSize
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        imageView.addGestureRecognizer(pinchGesture)
        
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        imageView.addGestureRecognizer(panGesture)
        
        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        imageView.addGestureRecognizer(longPressGesture)
        
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.image = image
        
        var transform = CGAffineTransform.identity
        transform = transform.scaledBy(x: scale, y: scale)
        transform = transform.translatedBy(x: offset.width / scale, y: offset.height / scale)
        uiView.transform = transform
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ZoomableImageView
        
        init(_ parent: ZoomableImageView) {
            self.parent = parent
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            if gesture.state == .began {
                parent.lastScale = parent.scale
            }
            parent.scale = parent.lastScale * gesture.scale
            parent.scale = max(1.0, min(parent.scale, 5.0))
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            if parent.scale > 1.0 {
                let translation = gesture.translation(in: gesture.view)
                if gesture.state == .began {
                    parent.lastOffset = parent.offset
                }
                parent.offset = CGSize(
                    width: parent.lastOffset.width + translation.x,
                    height: parent.lastOffset.height + translation.y
                )
            }
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            if parent.enableMagnifier {
                if gesture.state == .began || gesture.state == .changed {
                    if let view = gesture.view {
                        let location = gesture.location(in: view)
                        parent.magnifierPosition = location
                    }
                } else {
                    parent.magnifierPosition = nil
                }
            }
        }
    }
}

struct MagnifierView: View {
    let image: UIImage
    let position: CGPoint
    let viewSize: CGSize
    let radius: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: radius * 2, height: radius * 2)
                    .shadow(radius: 5)
                
                Image(uiImage: image)
                    .resizable()
                    .frame(width: radius * 4, height: radius * 4)
                    .scaleEffect(2.0)
                    .offset(
                        x: -position.x * 2 + radius,
                        y: -position.y * 2 + radius
                    )
                    .clipShape(Circle())
                
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: radius * 2, height: radius * 2)
                
                Circle()
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    .frame(width: radius * 2 - 4, height: radius * 2 - 4)
            }
            .position(
                x: min(max(radius + 20, position.x), geometry.size.width - radius - 20),
                y: min(max(radius + 20, position.y - 100), geometry.size.height - radius - 20)
            )
        }
    }
}

struct ComicSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var settings = ComicReadingSettings.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("阅读模式") {
                    ForEach(ComicReadingSettings.ReadingMode.allCases, id: \.self) { mode in
                        Button(action: {
                            settings.readingMode = mode
                            settings.saveSettings()
                        }) {
                            HStack {
                                Image(systemName: mode.icon)
                                    .foregroundColor(.blue)
                                Text(mode.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if settings.readingMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section("显示设置") {
                    Toggle("显示页码", isOn: $settings.showPageNumber)
                        .onChange(of: settings.showPageNumber) { _ in settings.saveSettings() }
                    
                    Toggle("显示进度条", isOn: $settings.showPageSlider)
                        .onChange(of: settings.showPageSlider) { _ in settings.saveSettings() }
                }
                
                Section("背景颜色") {
                    ForEach(ComicReadingSettings.ComicBackgroundColor.allCases, id: \.self) { color in
                        Button(action: {
                            settings.backgroundColor = color
                            settings.saveSettings()
                        }) {
                            HStack {
                                Circle()
                                    .fill(Color(color.color))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray, lineWidth: color == settings.backgroundColor ? 2 : 0)
                                    )
                                Text(color.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if settings.backgroundColor == color {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section("缩放设置") {
                    Toggle("双击缩放", isOn: $settings.doubleTapToZoom)
                        .onChange(of: settings.doubleTapToZoom) { _ in settings.saveSettings() }
                    
                    Toggle("捏合缩放", isOn: $settings.pinchToZoom)
                        .onChange(of: settings.pinchToZoom) { _ in settings.saveSettings() }
                }
                
                Section("放大镜") {
                    Toggle("启用放大镜", isOn: $settings.magnifierEnabled)
                        .onChange(of: settings.magnifierEnabled) { _ in settings.saveSettings() }
                    
                    if settings.magnifierEnabled {
                        Picker("放大镜大小", selection: $settings.magnifierSize) {
                            ForEach(ComicReadingSettings.MagnifierSize.allCases, id: \.self) { size in
                                Text(size.displayName).tag(size)
                            }
                        }
                        .onChange(of: settings.magnifierSize) { _ in settings.saveSettings() }
                    }
                }
                
                Section("其他") {
                    Toggle("保持屏幕常亮", isOn: $settings.keepScreenOn)
                        .onChange(of: settings.keepScreenOn) { _ in settings.saveSettings() }
                }
            }
            .navigationTitle("漫画设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ComicBookshelfView: View {
    @StateObject private var comicManager = ComicParserManager.shared
    @State private var showingFilePicker = false
    @State private var selectedComic: ComicParserManager.ComicBook?
    
    let comics: [ComicParserManager.ComicBook]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(comics) { comic in
                    ComicCoverView(comic: comic)
                        .onTapGesture {
                            selectedComic = comic
                        }
                }
            }
            .padding()
        }
        .navigationTitle("漫画书架")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingFilePicker = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            DocumentPickerView { url in
                handleComicImport(url: url)
            }
        }
        .fullScreenCover(item: $selectedComic) { comic in
            ComicReaderView(comicBook: comic)
        }
    }
    
    private func handleComicImport(url: URL) {
        Task {
            do {
                _ = try await comicManager.parseComic(at: url)
            } catch {
                print("Failed to import comic: \(error)")
            }
        }
    }
}

struct ComicCoverView: View {
    let comic: ComicParserManager.ComicBook
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let coverData = comic.coverImage, let uiImage = UIImage(data: coverData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(height: 150)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 150)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: comic.format.icon)
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            
            Text(comic.title)
                .font(.caption)
                .lineLimit(2)
                .foregroundColor(.primary)
            
            Text("\(comic.pageCount)页")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        var supportedTypes: [UTType] = [.archive, .pdf]
        if let zipType = UTType("public.zip-archive") {
            supportedTypes.append(zipType)
        }
        if let sevenZType = UTType("org.7-zip.7-zip-archive") {
            supportedTypes.append(sevenZType)
        }
        if let tarType = UTType("public.tar-archive") {
            supportedTypes.append(tarType)
        }
        if let gzipType = UTType("org.gnu.gnu-zip-archive") {
            supportedTypes.append(gzipType)
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            parent.onPick(url)
        }
    }
}

extension ComicParserManager.ComicBook: Identifiable {}
