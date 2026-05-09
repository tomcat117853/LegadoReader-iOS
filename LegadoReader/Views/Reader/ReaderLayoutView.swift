import SwiftUI

struct ReaderLayoutView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedLayout = "自定义"
    @State private var selectedColorIndex = 0
    @State private var brightness: Double = 0.5
    @State private var showLayoutManager = false
    @State private var showColorManager = false
    @State private var showColorTemplate = false
    
    private let layoutTypes = ["自定义", "初号", "小初", "一号", "一号宽", "小一", "二号", "小二", "三号", "小三"]
    
    private let colorSchemes = [
        ("护眼绿", Color(hex: "E8F5E9")!),
        ("白色", Color(hex: "FFFFFF")!),
        ("护眼黄", Color(hex: "F5E6D3")!),
        ("黑色", Color(hex: "1B1B1B")!),
        ("深灰", Color(hex: "2D2D2D")!),
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(layoutTypes, id: \.self) { layout in
                            Button(action: {
                                if layout == "自定义" {
                                    showLayoutManager = true
                                } else {
                                    selectedLayout = layout
                                }
                            }) {
                                Text(layout)
                                    .font(.subheadline)
                                    .foregroundColor(selectedLayout == layout ? .white : .primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(selectedLayout == layout ? Color(hex: "1B5E20")! : Color(.systemGray5))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                HStack(spacing: 12) {
                    ForEach(colorSchemes.indices, id: \.self) { index in
                        Button(action: {
                            selectedColorIndex = index
                        }) {
                            ZStack(alignment: .topTrailing) {
                                colorSchemes[index].1
                                    .frame(width: 56, height: 72)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedColorIndex == index ? Color(hex: "1B5E20")! : Color.clear, lineWidth: 2)
                                    )
                                
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .foregroundColor(selectedColorIndex == index ? Color(hex: "1B5E20")! : .white.opacity(0.7))
                                    .padding(2)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                HStack(spacing: 8) {
                    HStack(spacing: 0) {
                        Button(action: {}) {
                            Text("护眼")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color(hex: "1B5E20")!)
                                .cornerRadius(20, corners: [.topLeft, .bottomLeft])
                        }
                        
                        Button(action: {}) {
                            Text("修改")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color(hex: "1B5E20")!)
                                .cornerRadius(20, corners: [.topRight, .bottomRight])
                        }
                    }
                    
                    HStack(spacing: 0) {
                        Button(action: { showColorTemplate = true }) {
                            Text("配色")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color(hex: "1B5E20")!)
                                .cornerRadius(20, corners: [.topLeft, .bottomLeft])
                        }
                        
                        Button(action: { showColorManager = true }) {
                            Text("管理")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color(hex: "1B5E20")!)
                                .cornerRadius(20, corners: [.topRight, .bottomRight])
                        }
                    }
                }
                .padding(.horizontal)
                
                HStack {
                    Image(systemName: "sun.max")
                        .foregroundColor(.white)
                    
                    Slider(value: $brightness, in: 0...1)
                        .accentColor(Color(hex: "1B5E20")!)
                    
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(.white)
                    
                    Text("随系统")
                        .font(.caption)
                        .foregroundColor(Color(hex: "1B5E20")!)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .cornerRadius(20)
            }
            .navigationTitle("阅读布局")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showLayoutManager) {
                LayoutManagerView()
            }
            .sheet(isPresented: $showColorManager) {
                ColorSchemeManagerView()
            }
            .sheet(isPresented: $showColorTemplate) {
                ColorTemplateView()
            }
        }
    }
}

struct ColorTemplateView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var templateName = ""
    @State private var textColor = Color(hex: "333333")!
    @State private var widgetColor = Color(hex: "666666")!
    @State private var bgColor = Color(hex: "E8F5E9")!
    @State private var appTextColor = Color(hex: "B0B0B0")!
    @State private var appBgColor = Color(hex: "1B1B1B")!
    @State private var highlightColor = Color(hex: "1B5E20")!
    @State private var accentColor1 = Color(hex: "1B5E20")!
    @State private var accentColor2 = Color(hex: "1B5E20")!
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("创建阅读界面配色模板")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                
                VStack(spacing: 0) {
                    HStack {
                        Text("名称")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Text("颜色")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(Color(hex: "1B5E20")!)
                    .cornerRadius(8, corners: [.topLeft, .topRight])
                    
                    ColorRow(title: "阅读字体颜色", subtitle: "阅读内容的字体颜色", color: $textColor)
                    ColorRow(title: "阅读小部件颜色", subtitle: "小部件字体颜色", color: $widgetColor)
                    ColorRow(title: "阅读背景颜色", subtitle: "阅读内容的背景颜色", color: $bgColor)
                    ColorRow(title: "App阅读界面字体颜色", subtitle: "阅读界面上字体的颜色", color: $appTextColor)
                    ColorRow(title: "App阅读界面背景颜色", subtitle: "阅读界面上的背景颜色", color: $appBgColor)
                    ColorRow(title: "App阅读界面高亮色", subtitle: "阅读界面上选中或高亮的颜色", color: $highlightColor)
                    ColorRow(title: "阅读附加颜色1", subtitle: "可用于标记或排版强化", color: $accentColor1)
                    ColorRow(title: "阅读附加颜色2", subtitle: "可用于标记或排版强化", color: $accentColor2)
                        .background(Color(hex: "1B5E20")!)
                        .cornerRadius(8, corners: [.bottomLeft, .bottomRight])
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                
                Button(action: { dismiss() }) {
                    Text("取消")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 12)
                        .background(Color(hex: "1B5E20")!)
                        .cornerRadius(20)
                }
            }
            .background(Color(hex: "1B5E20")!.opacity(0.95))
            .presentationDetents([.medium])
        }
    }
}

struct ColorRow: View {
    let title: String
    let subtitle: String
    @Binding var color: Color
    
    var body: some View {
        HStack {
            color
                .frame(width: 48, height: 48)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.3), lineWidth: 1))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "1B5E20")!.opacity(0.5))
    }
}

struct LayoutManagerView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var isEditing = false
    @State private var selectedLayouts: [String] = []
    
    private let layouts = ["初号", "小初", "一号", "一号宽", "小一", "二号", "小二", "三号", "小三"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !isEditing {
                    Text("支持左滑操作;长按可切换编辑状态")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                
                List {
                    ForEach(layouts, id: \.self) { layout in
                        HStack {
                            if isEditing {
                                Button(action: {
                                    if selectedLayouts.contains(layout) {
                                        selectedLayouts.removeAll { $0 == layout }
                                    } else {
                                        selectedLayouts.append(layout)
                                    }
                                }) {
                                    Image(systemName: selectedLayouts.contains(layout) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedLayouts.contains(layout) ? Color(hex: "1B5E20")! : .secondary)
                                }
                            }
                            
                            Text(layout)
                                .font(.headline)
                            
                            Spacer()
                            
                            if !isEditing {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onLongPressGesture {
                            isEditing = true
                        }
                        .swipeActions(edge: .leading) {
                            Button("置顶") {
                                print("置顶 \(layout)")
                            }
                            .tint(.orange)
                            
                            Button("删除") {
                                print("删除 \(layout)")
                            }
                            .tint(.red)
                        }
                    }
                }
                
                if !isEditing {
                    Button(action: {}) {
                        Text("重置")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding()
                    }
                }
            }
            .navigationTitle("阅读布局管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
                
                if !isEditing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {}) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .toolbar(isEditing: isEditing) {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(action: {}) {
                        Text("删除")
                            .foregroundColor(.red)
                    }
                    
                    Button(action: {
                        selectedLayouts = layouts.filter { !selectedLayouts.contains($0) }
                    }) {
                        Text("反选")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {}) {
                        Text("导出")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        isEditing = false
                        selectedLayouts.removeAll()
                    }) {
                        Text("完成")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

struct ColorSchemeManagerView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var isEditing = false
    @State private var selectedSchemes: [String] = []
    
    private let colorSchemes = [
        ("白色恋人", "来自 App 颜色主题", Color(hex: "FFFFFF")!, Color(hex: "333333")!),
        ("蓝色传说", "来自 App 颜色主题", Color(hex: "1E3A5F")!, Color(hex: "E0E6ED")!),
        ("橘色撩心", "来自 App 颜色主题", Color(hex: "8B4513")!, Color(hex: "F5E6D3")!),
        ("黑夜琉璃", "来自 App 颜色主题", Color(hex: "0A0A0A")!, Color(hex: "B0B0B0")!),
        ("流光溢彩", "来自 App 颜色主题", Color(hex: "1a1a2e")!, Color(hex: "eaeaea")!),
        ("阅-浅绿", "仅用于阅读界面", Color(hex: "E8F5E9")!, Color(hex: "1B5E20")!),
        ("阅-青绿", "仅用于阅读界面", Color(hex: "E0F7FA")!, Color(hex: "00838F")!),
        ("阅-土棕", "仅用于阅读界面", Color(hex: "F5F5F5")!, Color(hex: "5D4037")!),
        ("阅-白灰", "仅用于阅读界面", Color(hex: "F5F5F5")!, Color(hex: "424242")!),
        ("阅-灰白", "仅用于阅读界面", Color(hex: "E0E0E0")!, Color(hex: "303030")!),
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !isEditing {
                    Text("支持左滑操作;长按可切换编辑状态")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                
                List {
                    ForEach(colorSchemes, id: \.0) { scheme in
                        HStack(spacing: 12) {
                            if isEditing {
                                Button(action: {
                                    if selectedSchemes.contains(scheme.0) {
                                        selectedSchemes.removeAll { $0 == scheme.0 }
                                    } else {
                                        selectedSchemes.append(scheme.0)
                                    }
                                }) {
                                    Image(systemName: selectedSchemes.contains(scheme.0) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedSchemes.contains(scheme.0) ? Color(hex: "1B5E20")! : .secondary)
                                }
                            }
                            
                            ColorPreviewView(bgColor: scheme.2, textColor: scheme.3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(scheme.0)
                                    .font(.headline)
                                
                                Text(scheme.1)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if !isEditing {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onLongPressGesture {
                            isEditing = true
                        }
                        .swipeActions(edge: .leading) {
                            Button("编辑") {
                                print("编辑 \(scheme.0)")
                            }
                            .tint(.blue)
                            
                            Button("导出") {
                                print("导出 \(scheme.0)")
                            }
                            .tint(.orange)
                            
                            Button("删除") {
                                print("删除 \(scheme.0)")
                            }
                            .tint(.red)
                        }
                    }
                }
            }
            .navigationTitle("阅读配色管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
                
                if !isEditing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {}) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .toolbar(isEditing: isEditing) {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(action: {}) {
                        Text("删除")
                            .foregroundColor(.red)
                    }
                    
                    Button(action: {
                        selectedSchemes = colorSchemes.filter { !selectedSchemes.contains($0.0) }.map { $0.0 }
                    }) {
                        Text("反选")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {}) {
                        Text("导出")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        isEditing = false
                        selectedSchemes.removeAll()
                    }) {
                        Text("完成")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

struct ColorPreviewView: View {
    let bgColor: Color
    let textColor: Color
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            bgColor
                .frame(width: 50, height: 60)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            
            VStack(spacing: 3) {
                Rectangle()
                    .fill(textColor)
                    .frame(height: 4)
                    .padding(.horizontal, 4)
                
                Rectangle()
                    .fill(textColor)
                    .frame(height: 3)
                    .padding(.horizontal, 4)
                
                Rectangle()
                    .fill(textColor)
                    .frame(height: 3)
                    .padding(.horizontal, 4)
                
                Rectangle()
                    .fill(textColor)
                    .frame(height: 3)
                    .padding(.horizontal, 4)
            }
            .padding(.top, 8)
            
            Image(systemName: "pencil")
                .font(.caption)
                .foregroundColor(textColor)
                .padding(2)
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct ReaderLayoutView_Previews: PreviewProvider {
    static var previews: some View {
        ReaderLayoutView()
    }
}