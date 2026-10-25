//
//  WidgetIntents.swift
//  DailyThreeWidgetExtension
//
//  Actions the widgets run without opening the app.
//

import AppIntents
import SwiftData
import WidgetKit

/// Edits today's entry in the shared store. Changes made here are picked up by the app and, through it, iCloud.
enum SharedStoreEditor {
    static func editToday(_ change: (DayEntry) -> Void) {
        do {
            let container = try WidgetStoreConfiguration.makeContainer()
            let context = ModelContext(container)
            let todayKey = DayEntry.makeDateKey(for: Date())
            let descriptor = FetchDescriptor<DayEntry>(predicate: #Predicate { $0.dateKey == todayKey })
            let entry = try context.fetch(descriptor).first ?? DayEntry(date: Date())
            if entry.modelContext == nil {
                context.insert(entry)
            }
            change(entry)
            try context.save()
        } catch {
            // If the store can't be opened, the widget simply keeps showing what it had.
        }
    }
}

/// Checks a task off, or back on, from a widget row.
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task"

    @Parameter(title: "Task Index")
    var index: Int

    init() {}

    init(index: Int) {
        self.index = index
    }

    func perform() async throws -> some IntentResult {
        SharedStoreEditor.editToday { entry in
            switch index {
            case 0: entry.taskOneDone.toggle()
            case 1: entry.taskTwoDone.toggle()
            case 2: entry.taskThreeDone.toggle()
            default: break
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Checks off the first task that's written but not done yet. This is the "big check" on the Next Up widget.
struct CompleteNextTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Next Task"

    init() {}

    func perform() async throws -> some IntentResult {
        SharedStoreEditor.editToday { entry in
            let slots: [(text: String, done: Bool)] = [
                (entry.taskOne, entry.taskOneDone),
                (entry.taskTwo, entry.taskTwoDone),
                (entry.taskThree, entry.taskThreeDone)
            ]
            guard let next = slots.firstIndex(where: { !$0.text.isBlank && !$0.done }) else { return }
            switch next {
            case 0: entry.taskOneDone = true
            case 1: entry.taskTwoDone = true
            default: entry.taskThreeDone = true
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
