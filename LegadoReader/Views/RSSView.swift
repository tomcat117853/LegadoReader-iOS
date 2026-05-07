import SwiftUI

struct RSSView: View {
    @EnvironmentObject var sourceStore: SourceStore
    @State private var showingAddSource = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sourceStore.rssSources) { source in
                    RSSSourceRow(source: source)
                }
            }
            .listStyle(.plain)
            .navigationTitle("订阅")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSource = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSource) {
                AddRSSSourceView()
            }
        }
    }
}

struct RSSSourceRow: View {
    let source: RSSSource
    
    var body: some View {
        HStack {
            // 图标
            if let icon = source.icon, let url = URL(string: icon) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "newspaper")
                            .foregroundColor(.blue)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(source.name)
                    .font(.system(size: 16, weight: .medium))
                Text(source.url)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if !source.isEnabled {
                Text("已禁用")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddRSSSourceView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var url = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("订阅源信息") {
                    TextField("名称", text: $name)
                    TextField("URL", text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("添加订阅源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSource()
                    }
                    .disabled(name.isEmpty || url.isEmpty)
                }
            }
        }
    }
    
    private func saveSource() {
        let source = RSSSource(name: name, url: url)
        // 保存订阅源
        dismiss()
    }
}
