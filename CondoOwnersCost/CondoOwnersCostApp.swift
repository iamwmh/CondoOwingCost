//
//  CondoOwnersCostApp.swift
//  CondoOwnersCost
//

import SwiftUI

@main
struct CondoOwnersCostApp: App {
    @State private var language = LanguageSettings()
    @State private var store = PortfolioStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(language)
                .environment(\.locale, language.language.locale)
                .tint(Theme.teal)
        }
    }
}
