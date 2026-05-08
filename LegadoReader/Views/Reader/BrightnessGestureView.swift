import SwiftUI
import UIKit

struct BrightnessGestureView: View {
    @StateObject private var brightnessManager = BrightnessManager.shared
    @State private var isAdjusting = false
    @State private var gestureOffset: CGFloat = 0
    @State private var startBrightness: CGFloat = 0
    @GestureState private var isDragging = false
    
    @State private var showingBrightnessIndicator = false
    @State private var indicatorBrightness: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isAdjusting {
                                isAdjusting = true
                                startBrightness = brightnessManager.brightness
                                showingBrightnessIndicator = true
                            }
                            
                            let delta = -value.translation.height / geometry.size.height
                            let newBrightness = min(1.0, max(0.0, startBrightness + delta))
                            brightnessManager.brightness = newBrightness
                            indicatorBrightness = newBrightness
                            gestureOffset = value.translation.height
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.3)) {
                                isAdjusting = false
                                showingBrightnessIndicator = false
                                gestureOffset = 0
                            }
                            brightnessManager.saveSettings()
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { scale in
                        }
                )
        }
        .overlay {
            if showingBrightnessIndicator {
                brightnessIndicatorOverlay
            }
        }
    }
    
    private var brightnessIndicatorOverlay: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.3), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: indicatorBrightness)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: brightnessIcon)
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
            }
            
            Text("\(Int(indicatorBrightness * 100))%")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .font(.caption2)
                Text("上滑增加")
                    .font(.caption)
            }
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7))
        )
        .transition(.scale.combined(with: .opacity))
    }
    
    private var brightnessIcon: String {
        if indicatorBrightness < 0.2 {
            return "sun.min"
        } else if indicatorBrightness < 0.5 {
            return "sun.max"
        } else {
            return "sun.max.fill"
        }
    }
}

struct TwoFingerBrightnessController: UIViewControllerRepresentable {
    @Binding var isActive: Bool
    let onBrightnessChange: (CGFloat) -> Void
    
    func makeUIViewController(context: Context) -> BrightnessGestureController {
        let controller = BrightnessGestureController()
        controller.onBrightnessChange = onBrightnessChange
        return controller
    }
    
    func updateUIViewController(_ uiViewController: BrightnessGestureController, context: Context) {
        uiViewController.isActive = isActive
    }
}

class BrightnessGestureController: UIViewController {
    var isActive = false
    var onBrightnessChange: ((CGFloat) -> Void)?
    
    private var initialBrightness: CGFloat = 0
    private var isGestureActive = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupGesture()
    }
    
    private func setupGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.minimumNumberOfTouches = 2
        panGesture.maximumNumberOfTouches = 2
        view.addGestureRecognizer(panGesture)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard isActive else { return }
        
        let translation = gesture.translation(in: view)
        
        switch gesture.state {
        case .began:
            isGestureActive = true
            initialBrightness = UIScreen.main.brightness
            NotificationCenter.default.post(name: .brightnessAdjustingStarted, object: nil)
            
        case .changed:
            let delta = -translation.y / view.bounds.height
            let newBrightness = min(1.0, max(0.0, initialBrightness + delta))
            UIScreen.main.brightness = newBrightness
            onBrightnessChange?(newBrightness)
            NotificationCenter.default.post(
                name: .brightnessValueChanged,
                object: nil,
                userInfo: ["brightness": newBrightness]
            )
            
        case .ended, .cancelled:
            isGestureActive = false
            NotificationCenter.default.post(name: .brightnessAdjustingEnded, object: nil)
            BrightnessManager.shared.saveSettings()
            
        default:
            break
        }
    }
}

extension Notification.Name {
    static let brightnessAdjustingStarted = Notification.Name("brightnessAdjustingStarted")
    static let brightnessValueChanged = Notification.Name("brightnessValueChanged")
    static let brightnessAdjustingEnded = Notification.Name("brightnessAdjustingEnded")
}

struct BrightnessIndicatorOverlay: View {
    @State private var brightness: CGFloat = UIScreen.main.brightness
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            if isVisible {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color.orange.opacity(0.3), lineWidth: 6)
                            .frame(width: 100, height: 100)
                        
                        Circle()
                            .trim(from: 0, to: brightness)
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                        
                        Image(systemName: brightnessIcon)
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                    }
                    
                    Text("\(Int(brightness * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("双指上下滑动调节亮度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(UIColor.systemBackground))
                        .shadow(color: .black.opacity(0.2), radius: 20)
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isVisible)
        .onReceive(NotificationCenter.default.publisher(for: .brightnessAdjustingStarted)) { _ in
            brightness = UIScreen.main.brightness
            isVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .brightnessValueChanged)) { notification in
            if let value = notification.userInfo?["brightness"] as? CGFloat {
                brightness = value
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .brightnessAdjustingEnded)) { _ in
            isVisible = false
        }
    }
    
    private var brightnessIcon: String {
        if brightness < 0.2 {
            return "sun.min"
        } else if brightness < 0.5 {
            return "sun.max"
        } else {
            return "sun.max.fill"
        }
    }
}
