import SwiftUI

struct ExploreView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var sourceStore: SourceStore
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("类型", selection: $selectedTab) {
                    Text("发现").tag(0)
                    Text("订阅").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if selectedTab == 0 {
                    DiscoverContent()
                } else {
                    RSSContent()
                }
            }
            .navigationTitle("探索")
        }
    }
}

struct DiscoverContent: View {
    @EnvironmentObject var sourceStore: SourceStore
    
    var body: some View {
        List {
            ForEach(sourceStore.bookSources.filter { $0.isEnabled }) { source in
                DiscoverSourceSection(source: source)
            }
        }
        .listStyle(.plain)
    }
}

struct RSSContent: View {
    @EnvironmentObject var sourceStore: SourceStore
    @State private var showingAddSource = false
    
    var body: some View {
        List {
            ForEach(sourceStore.rssSources) { source in
                RSSSourceRow(source: source)
            }
        }
        .listStyle(.plain)
        .overlay {
            if sourceStore.rssSources.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "newspaper")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("暂无订阅源")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Button("添加订阅") {
                        showingAddSource = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
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
