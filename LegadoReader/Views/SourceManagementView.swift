import SwiftUI

struct SourceManagementView: View {
    @EnvironmentObject var sourceStore: SourceStore
    @State private var showingImportSheet = false
    @State private var showingAddSource = false
    @State private var importText = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sourceStore.bookSources) { source in
                    BookSourceRow(source: source)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                // 删除书源
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            
                            Button {
                                sourceStore.toggleSourceEnabled(source)
                            } label: {
                                Label(source.isEnabled ? "禁用" : "启用", systemImage: source.isEnabled ? "pause" : "play")
                            }
                            .tint(source.isEnabled ? .orange : .green)
                        }
                }
            }
            .listStyle(.plain)
            .navigationTitle("书源管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: { showingImportSheet = true }) {
                            Label("导入书源", systemImage: "square.and.arrow.down")
                        }
                        Button(action: { showingAddSource = true }) {
                            Label("新建书源", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(sourceStore.bookSources.count) 个书源")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .sheet(isPresented: $showingImportSheet) {
                ImportSourceView(importText: $importText) {
                    importSources()
                }
            }
        }
    }
    
    private func importSources() {
        let count = sourceStore.importBookSources(from: importText)
        print("成功导入 \(count) 个书源")
        importText = ""
        showingImportSheet = false
    }
}

struct BookSourceRow: View {
    let source: BookSource
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(source.name)
                        .font(.system(size: 16, weight: .medium))
                    
                    if !source.isEnabled {
                        Text("已禁用")
                            .font(.system(size: 11))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                    }
                }
                
                Text(source.url)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text(source.type.displayName)
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    Text("权重: \(source.weight)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(source.isEnabled ? 1.0 : 0.6)
    }
}

struct ImportSourceView: View {
    @Binding var importText: String
    let onImport: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $importText)
                    .font(.system(size: 14))
                    .padding()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("支持格式:")
                        .font(.system(size: 14, weight: .medium))
                    Text("• Legado 书源 JSON")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("• 网络链接")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
            }
            .navigationTitle("导入书源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("导入") {
                        onImport()
                    }
                    .disabled(importText.isEmpty)
                }
            }
        }
    }
}
