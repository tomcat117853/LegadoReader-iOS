import SwiftUI

struct ReaderLayoutView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedLayout = "自定义"
    @State private var selectedColorIndex = 0
    @State private var fontSize: Double = 18
    @State private var showLayoutManager = false
    @State private var showColorManager = false
    
    private let layoutTypes = ["自定义", "初号", "小初", "一号", "一号宽", "小一", "二号", "小二", "三号", "小三"]
    
    private let colorSchemes = [
        ("护眼绿", Color(hex: "E8F5E9")!, Color(hex: "1B5E20")!),
        ("白色", Color(hex: "FFFFFF")!, Color(hex: "333333")!),
        ("护眼黄", Color(hex: "F5E6D3")!, Color(hex: "5D4037")!),
        ("黑色", Color(hex: "1B1B1B")!, Color(hex: "B0B0B0")!),
        ("深灰", Color(hex: "2D2D2D")!, Color(hex: "CCCCCC")!),
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
                
                VStack(spacing: 8) {
                    Text("配色")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        ForEach(colorSchemes.indices, id: \.self) { index in
                            Button(action: {
                                selectedColorIndex = index
                            }) {
                                VStack(spacing: 4) {
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
                                            .foregroundColor(colorSchemes[index].2)
                                            .padding(2)
                                    }
                                    
                                    Text(colorSchemes[index].0)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Button(action: {
                            showColorManager = true
                        }) {
                            VStack(spacing: 4) {
                                ZStack {
                                    Color(.systemGray5)
                                        .frame(width: 56, height: 72)
                                        .cornerRadius(8)
                                    
                                    Image(systemName: "plus")
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("更多")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Button(action: {}) {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.fill")
                            .foregroundColor(.white)
                        
                        Text("护眼")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hex: "1B5E20")!)
                    .cornerRadius(20)
                }
                
                Button(action: {}) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .foregroundColor(.white)
                        
                        Text("修改")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hex: "1B5E20")!)
                    .cornerRadius(20)
                }
                
                HStack {
                    Image(systemName: "sun.max")
                        .foregroundColor(.white)
                    
                    Slider(value: $fontSize, in: 12...32)
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
                        HStack {
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
                            
                            ZStack(alignment: .topTrailing) {
                                scheme.2
                                    .frame(width: 50, height: 60)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                                
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundColor(scheme.3)
                                    .padding(2)
                            }
                            
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

struct ReaderLayoutView_Previews: PreviewProvider {
    static var previews: some View {
        ReaderLayoutView()
    }
}