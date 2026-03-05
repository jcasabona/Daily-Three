//
//  SharedModels.swift
//  Daily Three
//
//  Created by Joe Casabona on 3/5/26.
//

import Foundation
import SwiftData

@Model
final class DayEntry {
    @Attribute(.unique) var dateKey: String
    var date: Date
    var taskOne: String
    var taskTwo: String
    var taskThree: String
    var taskOneDone: Bool
    var taskTwoDone: Bool
    var taskThreeDone: Bool
    var progressNote: String
    var completionNote: String

    init(date: Date) {
        let normalized = Calendar.current.startOfDay(for: date)
        self.date = normalized
        self.dateKey = DayEntry.makeDateKey(for: normalized)
        self.taskOne = ""
        self.taskTwo = ""
        self.taskThree = ""
        self.taskOneDone = false
        self.taskTwoDone = false
        self.taskThreeDone = false
        self.progressNote = ""
        self.completionNote = ""
    }

    static func makeDateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

@Model
final class AppSettings {
    var morningTime: Date
    var middayTime: Date
    var eveningTime: Date
    var theme: ThemeOption
    var appearanceModeRaw: String = AppearanceMode.system.rawValue

    @Transient var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }
        set { appearanceModeRaw = newValue.rawValue }
    }

    init() {
        let calendar = Calendar.current
        let today = Date()
        self.morningTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today) ?? today
        self.middayTime = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today) ?? today
        self.eveningTime = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: today) ?? today
        self.theme = .sunrise
        self.appearanceModeRaw = AppearanceMode.system.rawValue
    }
}

enum ThemeOption: String, CaseIterable, Codable {
    case sunrise
    case ocean
    case forest
    case graphite
}

enum AppearanceMode: String, CaseIterable, Codable {
    case system
    case light
    case dark
}

enum WidgetStoreConfiguration {
    static let appGroupID = "group.com.joecasabona.dailythree"
    private static let storeFileName = "DailyThree.store"

    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([DayEntry.self, AppSettings.self])
        let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            .map { $0.appendingPathComponent(storeFileName) }
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
