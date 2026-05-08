import SwiftUI

struct TextLayoutSettingsView: View {
    @StateObject private var layoutManager = TextLayoutManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(TextLayoutManager.TextLayout.allCases) { layout in
                        Button(action: {
                            layoutManager.setLayout(layout)
                        }) {
                            HStack {
                                Image(systemName: layout.icon)
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .frame(width: 40)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(layout.displayName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(layout == .horizontal ? "从左到右阅读，适合现代书籍" : "从右到左阅读，适合古典文学")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if layoutManager.currentLayout == layout {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("排版方式")
                } footer: {
                    Text("竖排是中国传统阅读方式，文字从右到左、从上到下排列")
                }
                
                if layoutManager.currentLayout == .vertical {
                    Section {
                        ForEach(TextLayoutManager.VerticalDirection.allCases) { direction in
                            Button(action: {
                                layoutManager.setVerticalDirection(direction)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(direction.displayName)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text(direction.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if layoutManager.verticalTextDirection == direction {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("竖排方向")
                    }
                }
                
                Section("间距调整") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("行间距")
                            Spacer()
                            Text("\(String(format: "%.1f", layoutManager.lineSpacingMultiplier))x")
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                        
                        Slider(
                            value: $layoutManager.lineSpacingMultiplier,
                            in: 1.0...2.5,
                            step: 0.1
                        )
                        .onChange(of: layoutManager.lineSpacingMultiplier) { _ in
                            layoutManager.setLineSpacing(layoutManager.lineSpacingMultiplier)
                        }
                        
                        HStack {
                            Text("1.0x")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("2.5x")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("段落间距")
                            Spacer()
                            Text("\(Int(layoutManager.paragraphSpacing))pt")
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                        
                        Slider(
                            value: $layoutManager.paragraphSpacing,
                            in: 0...32,
                            step: 4
                        )
                        .onChange(of: layoutManager.paragraphSpacing) { _ in
                            layoutManager.setParagraphSpacing(layoutManager.paragraphSpacing)
                        }
                        
                        HStack {
                            Text("0pt")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("32pt")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("文本对齐") {
                    ForEach(TextLayoutManager.TextAlignment.allCases) { alignment in
                        Button(action: {
                            layoutManager.setTextAlignment(alignment)
                        }) {
                            HStack {
                                Text(alignment.displayName)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if layoutManager.textAlignment == alignment {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section("预览") {
                    LayoutPreviewView()
                }
                
                Section {
                    Button("恢复默认设置") {
                        layoutManager.setLayout(.horizontal)
                        layoutManager.setVerticalDirection(.ttb)
                        layoutManager.setLineSpacing(1.5)
                        layoutManager.setParagraphSpacing(16)
                        layoutManager.setTextAlignment(.leading)
                    }
                    .foregroundColor(.orange)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("排版设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LayoutPreviewView: View {
    @StateObject private var layoutManager = TextLayoutManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if layoutManager.currentLayout == .horizontal {
                HorizontalPreview()
            } else {
                VerticalPreview()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct HorizontalPreview: View {
    @StateObject private var layoutManager = TextLayoutManager.shared
    
    var body: some View {
        Text("床前明月光，疑是地上霜。举头望明月，低头思故乡。")
            .font(.system(size: 14))
            .lineSpacing((layoutManager.lineSpacingMultiplier - 1) * 14)
            .multilineTextAlignment(getAlignment())
    }
    
    private func getAlignment() -> TextAlignment {
        switch layoutManager.textAlignment {
        case .leading: return .leading
        case .center: return .center
        case .justified: return .leading
        }
    }
}

struct VerticalPreview: View {
    @StateObject private var layoutManager = TextLayoutManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: (layoutManager.lineSpacingMultiplier - 1) * 14) {
            ForEach(Array("床前明月光"), id: \.self) { char in
                Text(String(char))
                    .font(.system(size: 14))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LayoutToggleButton: View {
    @StateObject private var layoutManager = TextLayoutManager.shared
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                layoutManager.toggleLayout()
            }
            onTap()
        }) {
            HStack(spacing: 6) {
                Image(systemName: layoutManager.currentLayout.icon)
                    .font(.system(size: 16))
                Text(layoutManager.currentLayout.displayName)
                    .font(.system(size: 14))
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct VerticalTextView: View {
    let text: String
    @StateObject private var layoutManager = TextLayoutManager.shared
    let fontSize: CGFloat
    let fontColor: Color
    let onTap: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollView(.vertical, showsIndicators: false) {
                    generateVerticalLayout(in: geometry.size)
                }
            }
            .rotationEffect(.degrees(layoutManager.verticalTextDirection == .btt ? 180 : 0))
        }
        .onTapGesture {
            onTap()
        }
    }
    
    private func generateVerticalLayout(in size: CGSize) -> some View {
        let charsPerRow = Int(size.height / (fontSize * layoutManager.lineSpacingMultiplier))
        let chars = Array(text)
        var rows: [[Character]] = []
        
        var currentRow: [Character] = []
        for (index, char) in chars.enumerated() {
            currentRow.append(char)
            
            if currentRow.count >= charsPerRow || index == chars.count - 1 {
                rows.append(currentRow)
                currentRow = []
            }
        }
        
        return HStack(alignment: .top, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                VStack(alignment: .trailing, spacing: (layoutManager.lineSpacingMultiplier - 1) * fontSize) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, char in
                        Text(String(char))
                            .font(.system(size: fontSize))
                            .foregroundColor(fontColor)
                    }
                }
            }
        }
        .padding()
    }
}

struct MixedLayoutTextView: View {
    let text: String
    @StateObject private var layoutManager = TextLayoutManager.shared
    let fontSize: CGFloat
    let fontColor: Color
    let onTap: () -> Void
    
    var body: some View {
        if layoutManager.currentLayout == .horizontal {
            HorizontalScrollTextView(
                text: text,
                fontSize: fontSize,
                fontColor: fontColor,
                onTap: onTap
            )
        } else {
            VerticalTextView(
                text: text,
                fontSize: fontSize,
                fontColor: fontColor,
                onTap: onTap
            )
        }
    }
}

struct HorizontalScrollTextView: View {
    let text: String
    let fontSize: CGFloat
    let fontColor: Color
    let onTap: () -> Void
    
    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(size: fontSize))
                .foregroundColor(fontColor)
                .lineSpacing((TextLayoutManager.shared.lineSpacingMultiplier - 1) * fontSize)
                .padding()
        }
        .onTapGesture {
            onTap()
        }
    }
}

struct TextLayoutSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        TextLayoutSettingsView()
    }
}
