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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataController)
        }
        .modelContainer(dataController.container)
    }
}
