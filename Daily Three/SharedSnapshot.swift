//
//  SharedSnapshot.swift
//  Daily Three
//
//  Created by Joe Casabona on 3/5/26.
//

import Foundation

struct SharedDailySnapshot: Codable {
    let date: Date
    var tasks: [String]
    var completed: [Bool]
}

enum SharedSnapshotStore {
    static let appGroupID = "group.com.joecasabona.dailythree"
    private static let snapshotKey = "daily-three-today-snapshot"

    static func save(_ snapshot: SharedDailySnapshot) {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func load() -> SharedDailySnapshot? {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(SharedDailySnapshot.self, from: data)
    }

    static func clear() {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        defaults.removeObject(forKey: snapshotKey)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
