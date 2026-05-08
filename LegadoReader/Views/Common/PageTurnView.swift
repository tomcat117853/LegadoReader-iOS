import SwiftUI

class PageTurnManager: ObservableObject {
    static let shared = PageTurnManager()
    
    @Published var pageTurnStyle: PageTurnStyle = .scroll
    
    enum PageTurnStyle: String, CaseIterable, Identifiable {
        case scroll = "滚动"
        case slide = "滑动"
        case cover = "覆盖"
        case simulate = "仿真"
        
        var id: String { rawValue }
    }
}

struct PageTurnView<Content: View>: View {
    let style: PageTurnManager.PageTurnStyle
    let content: Content
    let onTurn: (direction: TurnDirection) -> Void
    
    enum TurnDirection {
        case next
        case previous
    }
    
    @State private var offset = CGSize.zero
    @State private var isDragging = false
    
    init(style: PageTurnManager.PageTurnStyle, onTurn: @escaping (TurnDirection) -> Void, @ViewBuilder content: () -> Content) {
        self.style = style
        self.onTurn = onTurn
        self.content = content()
    }
    
    var body: some View {
        switch style {
        case .scroll:
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    content
                }
            }
        case .slide:
            SlidePageView(content: content, onTurn: onTurn)
        case .cover:
            CoverPageView(content: content, onTurn: onTurn)
        case .simulate:
            SimulatePageView(content: content, onTurn: onTurn)
        }
    }
}

struct SlidePageView<Content: View>: View {
    let content: Content
    let onTurn: (PageTurnView.TurnDirection) -> Void
    
    @State private var dragOffset = CGSize.zero
    @State private var lastDragTime = Date()
    
    var body: some View {
        content
            .offset(x: dragOffset.width)
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 100
                        
                        if value.translation.width > threshold {
                            onTurn(.previous)
                        } else if value.translation.width < -threshold {
                            onTurn(.next)
                        }
                        
                        dragOffset = .zero
                    }
            )
    }
}

struct CoverPageView<Content: View>: View {
    let content: Content
    let onTurn: (PageTurnView.TurnDirection) -> Void
    
    @State private var dragOffset = CGSize.zero
    @State private var isFlipping = false
    
    var body: some View {
        ZStack {
            content
                .rotation3DEffect(
                    .degrees(-dragOffset.width * 0.1),
                    axis: (x: 0, y: 1, z: 0)
                )
                .offset(x: dragOffset.width)
            
            if dragOffset.width < 0 {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.1))
                    .frame(width: abs(dragOffset.width), height: UIScreen.main.bounds.height)
                    .offset(x: UIScreen.main.bounds.width / 2 - abs(dragOffset.width) / 2)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    dragOffset = CGSize(width: max(-200, min(0, value.translation.width)), height: 0)
                }
                .onEnded { value in
                    if value.translation.width < -50 {
                        withAnimation(.easeOut) {
                            dragOffset = CGSize(width: -UIScreen.main.bounds.width, height: 0)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onTurn(.next)
                            dragOffset = .zero
                        }
                    } else {
                        withAnimation(.easeOut) {
                            dragOffset = .zero
                        }
                    }
                }
        )
    }
}

struct SimulatePageView<Content: View>: View {
    let content: Content
    let onTurn: (PageTurnView.TurnDirection) -> Void
    
    @State private var dragOffset = CGSize.zero
    @State private var cornerRadius: CGFloat = 0
    
    var body: some View {
        ZStack {
            content
                .clipShape(CustomCornerShape(corner: .topRight, radius: cornerRadius))
                .offset(x: dragOffset.width, y: dragOffset.height)
            
            if dragOffset.width < 0 && dragOffset.height < 0 {
                let shadowOpacity = min(1, abs(dragOffset.width) / 100)
                let shadowRadius = abs(dragOffset.width) / 10
                
                content
                    .offset(x: UIScreen.main.bounds.width + dragOffset.width, y: dragOffset.height)
                    .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: -5, y: 5)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    dragOffset = CGSize(
                        width: max(-200, min(0, value.translation.width)),
                        height: max(-200, min(0, value.translation.height))
                    )
                    cornerRadius = min(30, abs(dragOffset.width))
                }
                .onEnded { value in
                    let totalDistance = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)
                    
                    if totalDistance > 80 {
                        withAnimation(.easeOut(duration: 0.3)) {
                            dragOffset = CGSize(
                                width: -UIScreen.main.bounds.width,
                                height: -UIScreen.main.bounds.height
                            )
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onTurn(.next)
                            dragOffset = .zero
                            cornerRadius = 0
                        }
                    } else {
                        withAnimation(.easeOut) {
                            dragOffset = .zero
                            cornerRadius = 0
                        }
                    }
                }
        )
    }
}

struct CustomCornerShape: Shape {
    var corner: UIRectCorner
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corner,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct PageTurnSettingsView: View {
    @StateObject private var pageTurnManager = PageTurnManager.shared
    
    var body: some View {
        List {
            Section("翻页效果") {
                ForEach(PageTurnManager.PageTurnStyle.allCases) { style in
                    Button(action: {
                        pageTurnManager.pageTurnStyle = style
                    }) {
                        HStack {
                            Text(style.rawValue)
                            
                            Spacer()
                            
                            if pageTurnManager.pageTurnStyle == style {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            Section("翻页方向") {
                HStack {
                    Text("左右翻页")
                    Spacer()
                    Toggle("", isOn: .constant(true))
                }
                
                HStack {
                    Text("音量键翻页")
                    Spacer()
                    Toggle("", isOn: .constant(false))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("翻页设置")
    }
}
