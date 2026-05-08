import SwiftUI

struct FontMappingSettingsView: View {
    @StateObject private var mappingManager = FontMappingManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var selectedMapping: FontMappingManager.FontMapping?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Toggle("启用字体映射", isOn: $mappingManager.enabled)
                        .onChange(of: mappingManager.enabled) { value in
                            mappingManager.setEnabled(value)
                        }
                }
                
                Section {
                    HStack {
                        Text("默认字体")
                        Spacer()
                        Button(action: {
                            showingAddSheet = true
                        }) {
                            HStack(spacing: 8) {
                                Text(mappingManager.defaultFont)
                                    .foregroundColor(.blue)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("默认字体")
                }
                
                Section {
                    ForEach(mappingManager.fontMappings) { mapping in
                        Button(action: {
                            selectedMapping = mapping
                            showingEditSheet = true
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mapping.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(mapping.fontName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(mapping.characterRanges.count)个范围")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteMappings)
                } header: {
                    Text("字体映射")
                } footer: {
                    Text("字符范围按优先级从上到下匹配")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("字体映射")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                FontMappingEditSheet(mapping: nil)
            }
            .sheet(item: $selectedMapping) { mapping in
                FontMappingEditSheet(mapping: mapping)
            }
        }
    }
    
    private func deleteMappings(at offsets: IndexSet) {
        for index in offsets {
            let mapping = mappingManager.fontMappings[index]
            mappingManager.removeMapping(mapping)
        }
    }
}

struct FontMappingEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var mappingManager = FontMappingManager.shared
    
    @State private var mappingName: String = ""
    @State private var selectedFont: String = ""
    @State private var characterRanges: [FontMappingManager.FontMapping.CharacterRange] = []
    @State private var newRangeStart: String = ""
    @State private var newRangeEnd: String = ""
    @State private var showingFontPicker = false
    @State private var errorMessage: String = ""
    
    init(mapping: FontMappingManager.FontMapping?) {
        if let mapping = mapping {
            _mappingName = State(initialValue: mapping.name)
            _selectedFont = State(initialValue: mapping.fontName)
            _characterRanges = State(initialValue: mapping.characterRanges)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("映射名称", text: $mappingName)
                } header: {
                    Text("映射名称")
                }
                
                Section {
                    HStack {
                        Text("字体")
                        Spacer()
                        Button(action: {
                            showingFontPicker = true
                        }) {
                            HStack(spacing: 8) {
                                Text(selectedFont.isEmpty ? "选择字体" : mappingManager.getFontFamilyName(selectedFont))
                                    .foregroundColor(selectedFont.isEmpty ? .secondary : .blue)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("目标字体")
                }
                
                Section {
                    ForEach(characterRanges.indices, id: \.self) { index in
                        HStack {
                            TextField("起始字符", text: Binding(
                                get: { characterRanges[index].start },
                                set: { characterRanges[index] = FontMappingManager.FontMapping.CharacterRange(start: $0, end: characterRanges[index].end) }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            Text("-")
                            TextField("结束字符", text: Binding(
                                get: { characterRanges[index].end },
                                set: { characterRanges[index] = FontMappingManager.FontMapping.CharacterRange(start: characterRanges[index].start, end: $0) }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            Button(action: {
                                characterRanges.remove(at: index)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("起始", text: $newRangeStart)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        Text("-")
                        TextField("结束", text: $newRangeEnd)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        Button(action: addCharacterRange) {
                            Image(systemName: "plus")
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("字符范围")
                } footer: {
                    Text("每个范围包含起始和结束字符，支持Unicode字符")
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(mappingName.isEmpty ? "添加映射" : "编辑映射")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveMapping()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingFontPicker) {
                FontPickerView(selectedFont: $selectedFont)
            }
        }
    }
    
    private func addCharacterRange() {
        guard !newRangeStart.isEmpty && !newRangeEnd.isEmpty else { return }
        characterRanges.append(FontMappingManager.FontMapping.CharacterRange(start: newRangeStart, end: newRangeEnd))
        newRangeStart = ""
        newRangeEnd = ""
    }
    
    private func saveMapping() {
        let mapping = FontMappingManager.FontMapping(
            name: mappingName,
            fontName: selectedFont,
            characterRanges: characterRanges
        )
        
        if let error = mappingManager.validateMapping(mapping) {
            errorMessage = error
            return
        }
        
        mappingManager.addMapping(mapping)
        dismiss()
    }
}

struct FontPickerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var mappingManager = FontMappingManager.shared
    
    @Binding var selectedFont: String
    @State private var searchText: String = ""
    
    private var filteredFonts: [String] {
        if searchText.isEmpty {
            return mappingManager.getAllAvailableFonts()
        }
        return mappingManager.getAllAvailableFonts().filter {
            $0.localizedCaseInsensitiveContains(searchText) ||
            mappingManager.getFontFamilyName($0).localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索字体", text: $searchText)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding()
                
                List {
                    ForEach(filteredFonts, id: \.self) { fontName in
                        Button(action: {
                            selectedFont = fontName
                            dismiss()
                        }) {
                            HStack {
                                Text(mappingManager.getFontFamilyName(fontName))
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedFont == fontName {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择字体")
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
