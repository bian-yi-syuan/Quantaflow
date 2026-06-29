import SwiftUI

@main
struct PDFAPPApp: App {
    @StateObject private var store = QuoteStore()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(store)
                .environment(\.locale, Locale(identifier: store.appLanguage.localeIdentifier))
                .preferredColorScheme(store.isDarkMode ? .dark : .light)
                .id(store.appLanguage.rawValue)
        }
    }
}
