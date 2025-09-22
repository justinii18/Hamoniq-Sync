//
//  Hamoniq_SyncApp.swift
//  Hamoniq Sync
//
//  Created by Justin Adjei on 20/09/2025.
//

import SwiftUI
import SwiftData

@main
struct Hamoniq_SyncApp: App {
    // Use our centralized DataController for data management
    @StateObject private var dataController = DataController.shared
    @StateObject private var appViewModel: AppViewModel
    
    init() {
        let dataController = DataController.shared
        _dataController = StateObject(wrappedValue: dataController)
        _appViewModel = StateObject(wrappedValue: AppViewModel(dataController: dataController))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataController)
                .environmentObject(appViewModel)
        }
        .modelContainer(dataController.container)
    }
}
