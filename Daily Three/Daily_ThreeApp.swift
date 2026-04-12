//
//  Daily_ThreeApp.swift
//  Daily Three
//
//  Created by Joe Casabona on 3/5/26.
//

import SwiftUI
import SwiftData
import Foundation

@main
struct Daily_ThreeApp: App {
    @State private var router = DeepLinkRouter()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DayEntry.self,
            AppSettings.self,
        ])
        let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedSnapshotStore.appGroupID)
            .map { $0.appendingPathComponent("DailyThree.store") }
        let modelConfiguration: ModelConfiguration
        if let storeURL {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .automatic
            )
        } else {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
        }

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(router)
        }
        .modelContainer(sharedModelContainer)
    }
}
