import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var bookStore: BookStore
    @EnvironmentObject var sourceStore: SourceStore
    @State private var showSidebar = false
    @State private var sidebarOffset: CGFloat = 0
    @State private var startX: CGFloat = 0
    
    let sidebarWidth: CGFloat = UIScreen.main.bounds.width * 0.85
    
    var body: some View {
        ZStack(alignment: .leading) {
            SidebarMenuView()
                .frame(width: sidebarWidth)
                .offset(x: -sidebarWidth + sidebarOffset)
                .edgesIgnoringSafeArea(.all)
            
            mainContent
                .offset(x: sidebarOffset)
                .background(Color(.systemBackground))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.startLocation.x < 50 {
                                let translation = value.translation.width
                                if translation > 0 {
                                    sidebarOffset = min(translation, sidebarWidth)
                                }
                            }
                        }
                        .onEnded { value in
                            if value.translation.width > sidebarWidth / 2 {
                                withAnimation(.spring()) {
                                    sidebarOffset = sidebarWidth
                                    showSidebar = true
                                }
                            } else {
                                withAnimation(.spring()) {
                                    sidebarOffset = 0
                                    showSidebar = false
                                }
                            }
                        }
                )
            
            if showSidebar {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            sidebarOffset = 0
                            showSidebar = false
                        }
                    }
                    .offset(x: sidebarWidth)
            }
        }
        .statusBarHidden(showSidebar)
    }
    
    private var mainContent: some View {
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