import SwiftUI

@main
struct AruKeibaApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task { await store.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await store.refresh() }
                    }
                }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { ThisWeekView() }
                .tabItem { Label("今週", systemImage: "figure.walk") }
            NavigationStack { HistoryView() }
                .tabItem { Label("履歴", systemImage: "list.bullet.rectangle") }
            NavigationStack { SettingsView() }
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .tint(Theme.turf)
    }
}

enum Theme {
    static let turf = Color(red: 0.13, green: 0.55, blue: 0.33)
    static let debt = Color(red: 0.85, green: 0.22, blue: 0.22)
    static let race = Color(red: 0.88, green: 0.56, blue: 0.08)
}

/// 角丸のカード
struct Card<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}
