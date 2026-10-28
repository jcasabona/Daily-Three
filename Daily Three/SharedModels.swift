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

    // Todoist links, one per task slot. An empty ID means the slot isn't linked. The "synced" values record
    // what Todoist and the app last agreed on, so a later sync can tell which side changed.
    var todoistIDOne: String = ""
    var todoistIDTwo: String = ""
    var todoistIDThree: String = ""
    var todoistSyncedContentOne: String = ""
    var todoistSyncedContentTwo: String = ""
    var todoistSyncedContentThree: String = ""
    var todoistSyncedDoneOne: Bool = false
    var todoistSyncedDoneTwo: Bool = false
    var todoistSyncedDoneThree: Bool = false

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
    var themeRaw: String = ThemeOption.graphite.rawValue
    var appearanceModeRaw: String = AppearanceMode.system.rawValue
    var hasCompletedOnboarding: Bool?
    /// Comma-separated `Calendar` weekday numbers (1 = Sunday ... 7 = Saturday) the user has turned off.
    var excludedWeekdaysRaw: String = ""
    /// Create new Todoist tasks for unlinked tasks typed in the app.
    var todoistCreatesTasks: Bool = true
    /// Project new tasks are created in. Empty means the Todoist Inbox.
    var todoistProjectID: String = ""
    var todoistProjectName: String = ""

    @Transient var excludedWeekdays: Set<Int> {
        get { Set(excludedWeekdaysRaw.split(separator: ",").compactMap { Int($0) }) }
        set { excludedWeekdaysRaw = newValue.sorted().map(String.init).joined(separator: ",") }
    }

    @Transient var theme: ThemeOption {
        get { ThemeOption(rawValue: themeRaw) ?? .graphite }
        set { themeRaw = newValue.rawValue }
    }

    @Transient var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }
        set { appearanceModeRaw = newValue.rawValue }
    }

    /// How far this record is from a fresh install. Used to choose which duplicate to keep.
    var customizationScore: Int {
        let calendar = Calendar.current
        func minutes(_ date: Date) -> Int {
            calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        }
        var score = 0
        if hasCompletedOnboarding == true { score += 2 }
        if themeRaw != ThemeOption.graphite.rawValue { score += 1 }
        if appearanceModeRaw != AppearanceMode.system.rawValue { score += 1 }
        if !excludedWeekdaysRaw.isEmpty { score += 1 }
        if !todoistCreatesTasks { score += 1 }
        if !todoistProjectID.isEmpty { score += 1 }
        if minutes(morningTime) != 9 * 60 { score += 1 }
        if minutes(middayTime) != 12 * 60 { score += 1 }
        if minutes(eveningTime) != 17 * 60 { score += 1 }
        return score
    }

    /// Every field as text, so two records with the same score still sort the same way on every device.
    var tieBreaker: String {
        [String(hasCompletedOnboarding ?? false), themeRaw, appearanceModeRaw, excludedWeekdaysRaw,
         String(todoistCreatesTasks), todoistProjectID, todoistProjectName,
         String(Int(morningTime.timeIntervalSinceReferenceDate)),
         String(Int(middayTime.timeIntervalSinceReferenceDate)),
         String(Int(eveningTime.timeIntervalSinceReferenceDate))].joined(separator: "|")
    }

    init() {
        let calendar = Calendar.current
        let today = Date()
        self.morningTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today) ?? today
        self.middayTime = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today) ?? today
        self.eveningTime = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: today) ?? today
        self.themeRaw = ThemeOption.graphite.rawValue
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

    static func merge(from source: DayEntry, into target: DayEntry) {
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
            // Every device must pick the same record, or each deletes the other's and the settings never settle.
            // Fetch order differs per device, so rank by content: the most customized record wins.
            guard let keeper = all.max(by: { ($0.customizationScore, $0.tieBreaker) < ($1.customizationScore, $1.tieBreaker) }) else { return }
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
