import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var bookStore: BookStore
    @EnvironmentObject var sourceStore: SourceStore
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BookshelfView()
                .tabItem {
                    Image(systemName: "books.vertical.fill")
                    Text("书架")
                }
                .tag(0)
            
            ExploreView()
                .tabItem {
                    Image(systemName: "safari.fill")
                    Text("探索")
                }
                .tag(1)
            
            LibraryView()
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("本地")
                }
                .tag(2)
            
            ReadingProgressView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("阅读")
                }
                .tag(3)
            
            ComicBookshelfView()
                .tabItem {
                    Image(systemName: "photo.on.rectangle")
                    Text("漫画")
                }
                .tag(4)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("设置")
                }
                .tag(5)
        }
        .accentColor(.blue)
    }
}