//
//  BetterSleepApp.swift
//  BetterSleep
//
//  Created by Little Gragon on 2025/8/28.
//

import SwiftUI

@main
struct BetterSleepApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
