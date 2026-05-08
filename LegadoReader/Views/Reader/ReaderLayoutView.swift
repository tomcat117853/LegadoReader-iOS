import SwiftUI

struct ReaderLayoutView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedLayout = "自定义"
    @State private var selectedColorIndex = 0
    @State private var fontSize: Double = 18
    @State private var showLayoutManager = false
    
    private let layoutTypes = ["自定义", "常规", "紧凑型", "中号型", "宽松型"]
    
    private let colorSchemes = [
        Color(hex: "E8F5E9")!, // 护眼绿
        Color(hex: "F5F5F5")!, // 白色
        Color(hex: "F5E6D3")!, // 护眼黄
        Color(hex: "1B1B1B")!, // 黑色
        Color(hex: "2D2D2D")!, // 深灰
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(layoutTypes, id: \.self) { layout in
                        Button(action: { selectedLayout = layout }) {
                            Text(layout)
                                .font(.subheadline)
                                .foregroundColor(selectedLayout == layout ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedLayout == layout ? Color.red : Color(.systemGray5))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                
                HStack(spacing: 8) {
                    ForEach(colorSchemes.indices, id: \.self) { index in
                        Button(action: { selectedColorIndex = index }) {
                            ZStack(alignment: .topTrailing) {
                                colorSchemes[index]
                                    .frame(width: 60, height: 80)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedColorIndex == index ? Color.green : Color.clear, lineWidth: 2)
                                    )
                                
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundColor(selectedColorIndex == index ? .green : .white.opacity(0.7))
                                    .padding(2)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                HStack(spacing: 12) {
                    Button(action: {}) {
                        Text("护眼")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color(hex: "1B5E20")!)
                            .cornerRadius(20)
                    }
                    
                    Button(action: {}) {
                        Text("修改")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color(hex: "1B5E20")!)
                            .cornerRadius(20)
                    }
                    
                    Button(action: {}) {
                        Text("配色")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color(hex: "1B5E20")!)
                            .cornerRadius(20)
                    }
                    
                    Button(action: { showLayoutManager = true }) {
                        Text("管理")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color(hex: "1B5E20")!)
                            .cornerRadius(20)
                    }
                }
                
                HStack {
                    Image(systemName: "sun.max")
                        .foregroundColor(.white)
                    
                    Slider(value: $fontSize, in: 12...32)
                        .accentColor(Color.green)
                    
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(.white)
                    
                    Text("随系统")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(hex: "1B5E20")!)
                .cornerRadius(20)
            }
            .background(Color(hex: "1B5E20")!)
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
        }
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
                                        .foregroundColor(selectedLayouts.contains(layout) ? .red : .secondary)
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

extension Color {
    init?(hex: String) {
        let hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexString.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct ReaderLayoutView_Previews: PreviewProvider {
    static var previews: some View {
        ReaderLayoutView()
    }
}
