//
//  WidgetData.swift
//  DailyThreeWidgetExtension
//
//  What the widgets show, how it's loaded from the shared store, and the timeline providers.
//

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// MARK: - Snapshot

struct DailySnapshot {
    let date: Date
    var tasks: [String]
    var completed: [Bool]
    var theme: ThemeOption
    var progressNote: String = ""
    var completionNote: String = ""

    var completedCount: Int { completed.filter { $0 }.count }
    var progress: Double { Double(completedCount) / 3.0 }
    var hasAnyTasks: Bool { tasks.contains { !$0.isBlank } }
    var hasJournal: Bool { !progressNote.isBlank || !completionNote.isBlank }

    func task(at index: Int) -> String { tasks[safe: index] ?? "" }
    func isDone(at index: Int) -> Bool { completed[safe: index] ?? false }

    /// The first task that is written but not yet done.
    var nextTaskIndex: Int? {
        (0..<3).first { !task(at: $0).isBlank && !isDone(at: $0) }
    }

    /// Everything that is set has been checked off.
    var isAllDone: Bool {
        hasAnyTasks && nextTaskIndex == nil
    }

    static func empty(theme: ThemeOption) -> DailySnapshot {
        DailySnapshot(date: .now, tasks: ["", "", ""], completed: [false, false, false], theme: theme)
    }

    /// Sample content for the widget gallery, placeholders and previews.
    static let sample = DailySnapshot(
        date: .now,
        tasks: ["Finish the quarterly report", "Plan the Duo layout", "Gym at 5"],
        completed: [true, false, false],
        theme: .graphite,
        progressNote: "The report is drafted. It just needs the final numbers.",
        completionNote: ""
    )

    func with(theme: ThemeOption) -> DailySnapshot {
        var copy = self
        copy.theme = theme
        return copy
    }
}

extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

// MARK: - Loading

enum SnapshotLoader {
    /// Today's tasks and notes from the shared store, or an empty snapshot if there's nothing (or it can't be read).
    static func loadToday() -> DailySnapshot {
        do {
            let container = try WidgetStoreConfiguration.makeContainer()
            let context = ModelContext(container)
            let theme = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first?.theme ?? .graphite
            let todayKey = DayEntry.makeDateKey(for: Date())
            let descriptor = FetchDescriptor<DayEntry>(predicate: #Predicate { $0.dateKey == todayKey })
            guard let entry = try context.fetch(descriptor).first else { return .empty(theme: theme) }
            return DailySnapshot(date: entry.date,
                                 tasks: [entry.taskOne, entry.taskTwo, entry.taskThree],
                                 completed: [entry.taskOneDone, entry.taskTwoDone, entry.taskThreeDone],
                                 theme: theme,
                                 progressNote: entry.progressNote,
                                 completionNote: entry.completionNote)
        } catch {
            return .empty(theme: .graphite)
        }
    }

    /// Refresh in half an hour, or just after midnight so a new day starts fresh.
    static func nextRefresh(from now: Date = .now) -> Date {
        let calendar = Calendar.current
        let halfHour = now.addingTimeInterval(30 * 60)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return halfHour }
        return min(halfHour, tomorrow.addingTimeInterval(60))
    }
}

// MARK: - Simple (non-configurable) widgets

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: DailySnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let snapshot = context.isPreview ? DailySnapshot.sample : SnapshotLoader.loadToday()
        completion(SnapshotEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: SnapshotLoader.loadToday())
        completion(Timeline(entries: [entry], policy: .after(SnapshotLoader.nextRefresh())))
    }
}

// MARK: - Today's Three (configurable)

struct TodaysThreeConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Today's Three"
    static var description = IntentDescription("Your three tasks, with an option to show your journal notes on the larger sizes.")

    @Parameter(title: "Show journal notes", default: true)
    var showJournal: Bool

    init() {}
}

struct TodaysThreeEntry: TimelineEntry {
    let date: Date
    let snapshot: DailySnapshot
    let showJournal: Bool
}

struct TodaysThreeProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TodaysThreeEntry {
        TodaysThreeEntry(date: .now, snapshot: .sample, showJournal: true)
    }

    func snapshot(for configuration: TodaysThreeConfiguration, in context: Context) async -> TodaysThreeEntry {
        let snapshot = context.isPreview ? DailySnapshot.sample : SnapshotLoader.loadToday()
        return TodaysThreeEntry(date: .now, snapshot: snapshot, showJournal: configuration.showJournal)
    }

    func timeline(for configuration: TodaysThreeConfiguration, in context: Context) async -> Timeline<TodaysThreeEntry> {
        let entry = TodaysThreeEntry(date: .now, snapshot: SnapshotLoader.loadToday(), showJournal: configuration.showJournal)
        return Timeline(entries: [entry], policy: .after(SnapshotLoader.nextRefresh()))
    }
}
