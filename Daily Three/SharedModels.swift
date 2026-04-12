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
    var dateKey: String = ""
    var date: Date = Date()
    var taskOne: String = ""
    var taskTwo: String = ""
    var taskThree: String = ""
    var taskOneDone: Bool = false
    var taskTwoDone: Bool = false
    var taskThreeDone: Bool = false
    var progressNote: String = ""
    var completionNote: String = ""

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
    var morningTime: Date = Date()
    var middayTime: Date = Date()
    var eveningTime: Date = Date()
    var themeRaw: String = ThemeOption.sunrise.rawValue
    var appearanceModeRaw: String = AppearanceMode.system.rawValue
    var hasCompletedOnboarding: Bool?

    @Transient var theme: ThemeOption {
        get { ThemeOption(rawValue: themeRaw) ?? .sunrise }
        set { themeRaw = newValue.rawValue }
    }

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
        self.themeRaw = ThemeOption.sunrise.rawValue
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
    static let appGroupID = "group.goodhouse.dailythree"
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

// MARK: - CloudKit Deduplication

enum DayEntryDeduplicator {
    /// Merges duplicate DayEntry records that share the same dateKey.
    @MainActor
    static func deduplicateIfNeeded(context: ModelContext) {
        do {
            let allEntries = try context.fetch(FetchDescriptor<DayEntry>(sortBy: [SortDescriptor(\.date)]))

            var grouped: [String: [DayEntry]] = [:]
            for entry in allEntries {
                grouped[entry.dateKey, default: []].append(entry)
            }

            for (_, entries) in grouped where entries.count > 1 {
                let sorted = entries.sorted { score($0) > score($1) }
                let keeper = sorted[0]
                for duplicate in sorted.dropFirst() {
                    merge(from: duplicate, into: keeper)
                    context.delete(duplicate)
                }
            }

            if context.hasChanges {
                try context.save()
            }
        } catch {
            // Best-effort deduplication
        }
    }

    private static func score(_ entry: DayEntry) -> Int {
        var s = 0
        if !entry.taskOne.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { s += 1 }
        if !entry.taskTwo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { s += 1 }
        if !entry.taskThree.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { s += 1 }
        if entry.taskOneDone { s += 1 }
        if entry.taskTwoDone { s += 1 }
        if entry.taskThreeDone { s += 1 }
        if !entry.progressNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { s += 1 }
        if !entry.completionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { s += 1 }
        return s
    }

    private static func merge(from source: DayEntry, into target: DayEntry) {
        if target.taskOne.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            target.taskOne = source.taskOne
        }
        if target.taskTwo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            target.taskTwo = source.taskTwo
        }
        if target.taskThree.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            target.taskThree = source.taskThree
        }
        if source.taskOneDone { target.taskOneDone = true }
        if source.taskTwoDone { target.taskTwoDone = true }
        if source.taskThreeDone { target.taskThreeDone = true }
        if !source.progressNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && target.progressNote != source.progressNote {
            if target.progressNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                target.progressNote = source.progressNote
            } else if source.progressNote.count > target.progressNote.count {
                target.progressNote = source.progressNote
            }
        }
        if !source.completionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && target.completionNote != source.completionNote {
            if target.completionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                target.completionNote = source.completionNote
            } else if source.completionNote.count > target.completionNote.count {
                target.completionNote = source.completionNote
            }
        }
    }
}

enum AppSettingsDeduplicator {
    /// Keeps one AppSettings record, deletes duplicates.
    @MainActor
    static func deduplicateIfNeeded(context: ModelContext) {
        do {
            let all = try context.fetch(FetchDescriptor<AppSettings>())
            guard all.count > 1 else { return }
            let keeper = all.first(where: { $0.hasCompletedOnboarding == true }) ?? all[0]
            for settings in all where settings !== keeper {
                context.delete(settings)
            }
            if context.hasChanges {
                try context.save()
            }
        } catch {
            // Best-effort deduplication
        }
    }
}
