//
//  Shortcuts.swift
//  Daily Three
//
//  Created by Joe Casabona on 3/7/26.
//

import AppIntents
import Foundation
import SwiftData
import WidgetKit

@MainActor
private func fetchContext(for date: Date?) throws -> (ModelContext, Date) {
    let container = try WidgetStoreConfiguration.makeContainer()
    let context = ModelContext(container)
    return (context, date ?? Date())
}

struct GetTasksIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Tasks"
    static var description = IntentDescription("Fetches three tasks for a date.")
    static var openAppWhenRun = false

    @Parameter(title: "Date")
    var date: Date?

    @Parameter(title: "Include completed tasks")
    var includeCompleted: Bool

    init() {
        self.date = nil
        self.includeCompleted = false
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let tasks = try await loadTasks(date: date, includeCompleted: includeCompleted)
        let value = tasks.isEmpty ? "No tasks set" : tasks.joined(separator: "\n")
        return .result(value: value)
    }

    private func loadTasks(date: Date?, includeCompleted: Bool) async throws -> [String] {
        let (context, keyDate) = try await fetchContext(for: date)
        let dateKey = DayEntry.makeDateKey(for: keyDate)
        let descriptor = FetchDescriptor<DayEntry>(predicate: #Predicate { $0.dateKey == dateKey })
        guard let entry = try context.fetch(descriptor).first else { return [] }

        let rawTasks = [entry.taskOne, entry.taskTwo, entry.taskThree]
        let completed = [entry.taskOneDone, entry.taskTwoDone, entry.taskThreeDone]

        return rawTasks.enumerated().compactMap { index, task in
            let trimmed = task.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if includeCompleted {
                return trimmed
            }
            let isDone = index < completed.count ? completed[index] : false
            return isDone ? nil : trimmed
        }
    }
}

struct GetProgressNotesIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Progress Notes"
    static var description = IntentDescription("Fetches progress notes for a date.")
    static var openAppWhenRun = false

    @Parameter(title: "Date")
    var date: Date?

    init() {
        self.date = nil
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let value = try await loadNote(for: \.progressNote, date: date)
        return .result(value: value)
    }

    private func loadNote(for keyPath: KeyPath<DayEntry, String>, date: Date?) async throws -> String {
        let (context, keyDate) = try await fetchContext(for: date)
        let dateKey = DayEntry.makeDateKey(for: keyDate)
        let descriptor = FetchDescriptor<DayEntry>(predicate: #Predicate { $0.dateKey == dateKey })
        guard let entry = try context.fetch(descriptor).first else { return "No entry for that date" }
        let note = entry[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines)
        let dateText = entry.date.formatted(date: .abbreviated, time: .omitted)
        let body = note.isEmpty ? "No notes yet" : note
        return "\(dateText): \(body)"
    }
}

struct GetCompletionNotesIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Completion Notes"
    static var description = IntentDescription("Fetches completion notes for a date.")
    static var openAppWhenRun = false

    @Parameter(title: "Date")
    var date: Date?

    init() {
        self.date = nil
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let value = try await loadNote(for: \.completionNote, date: date)
        return .result(value: value)
    }

    private func loadNote(for keyPath: KeyPath<DayEntry, String>, date: Date?) async throws -> String {
        let (context, keyDate) = try await fetchContext(for: date)
        let dateKey = DayEntry.makeDateKey(for: keyDate)
        let descriptor = FetchDescriptor<DayEntry>(predicate: #Predicate { $0.dateKey == dateKey })
        guard let entry = try context.fetch(descriptor).first else { return "No entry for that date" }
        let note = entry[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines)
        let dateText = entry.date.formatted(date: .abbreviated, time: .omitted)
        let body = note.isEmpty ? "No notes yet" : note
        return "\(dateText): \(body)"
    }
}

struct AddTasksIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Tasks"
    static var description = IntentDescription("Replaces today's three tasks with the provided list.")
    static var openAppWhenRun = false

    @Parameter(title: "Tasks", description: "Provide up to three tasks. Separate with new lines or commas.")
    var tasksText: String

    @Parameter(title: "Only fill empty slots", description: "If on, fills only empty task slots instead of replacing all three.")
    var onlyFillEmpty: Bool?

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let tasks = parseTasks(tasksText)
        guard !tasks.isEmpty else { return .result(value: "No tasks provided") }

        let (context, keyDate) = try await fetchContext(for: Date())
        let todayKey = DayEntry.makeDateKey(for: keyDate)
        let descriptor = FetchDescriptor<DayEntry>(predicate: #Predicate { $0.dateKey == todayKey })
        let entry = try context.fetch(descriptor).first ?? DayEntry(date: keyDate)
        if entry.modelContext == nil {
            context.insert(entry)
        }

        let fillEmptyOnly = onlyFillEmpty ?? false
        if fillEmptyOnly {
            applyTasksToEmptySlots(tasks, entry: entry)
        } else {
            applyTasksReplacing(tasks, entry: entry)
        }

        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result(value: "Tasks updated")
    }

    private func parseTasks(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let lines = text.split(whereSeparator: { $0.isNewline }).map { String($0) }
        let rawParts: [String]
        if lines.count > 1 {
            rawParts = lines
        } else {
            let commaParts = text.split(separator: ",").map { String($0) }
            if commaParts.count > 1 {
                rawParts = commaParts
            } else {
                let andParts = text.components(separatedBy: " and ")
                rawParts = andParts
            }
        }

        return rawParts
            .map { normalizeTask($0) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .map { $0 }
    }

    private func normalizeTask(_ value: String) -> String {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["- ", "• ", "* "] {
            if text.hasPrefix(prefix) {
                text.removeFirst(prefix.count)
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applyTasksReplacing(_ tasks: [String], entry: DayEntry) {
        let padded = tasks + Array(repeating: "", count: max(0, 3 - tasks.count))
        entry.taskOne = padded.count > 0 ? padded[0] : ""
        entry.taskTwo = padded.count > 1 ? padded[1] : ""
        entry.taskThree = padded.count > 2 ? padded[2] : ""
        entry.taskOneDone = false
        entry.taskTwoDone = false
        entry.taskThreeDone = false
    }

    private func applyTasksToEmptySlots(_ tasks: [String], entry: DayEntry) {
        var remaining = tasks
        if entry.taskOne.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let next = remaining.first {
            entry.taskOne = next
            entry.taskOneDone = false
            remaining.removeFirst()
        }
        if entry.taskTwo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let next = remaining.first {
            entry.taskTwo = next
            entry.taskTwoDone = false
            remaining.removeFirst()
        }
        if entry.taskThree.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let next = remaining.first {
            entry.taskThree = next
            entry.taskThreeDone = false
            remaining.removeFirst()
        }
    }
}

struct AddProgressNotesIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Progress Notes"
    static var description = IntentDescription("Appends to today's progress notes.")
    static var openAppWhenRun = false

    @Parameter(title: "Notes", description: "The text to add to the progress notes.")
    var notes: String

    @Parameter(title: "Overwrite existing notes", description: "If on, replaces what's already there.")
    var overwrite: Bool?

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .result(value: "No notes provided") }

        let (context, keyDate) = try await fetchContext(for: Date())
        let todayKey = DayEntry.makeDateKey(for: keyDate)
        let descriptor = FetchDescriptor<DayEntry>(predicate: #Predicate { $0.dateKey == todayKey })
        let entry = try context.fetch(descriptor).first ?? DayEntry(date: keyDate)
        if entry.modelContext == nil {
            context.insert(entry)
        }

        let shouldOverwrite = overwrite ?? false
        if shouldOverwrite || entry.progressNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            entry.progressNote = trimmed
        } else {
            entry.progressNote = "\(entry.progressNote)\n\n\(trimmed)"
        }

        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result(value: "Progress notes updated")
    }
}

struct AddCompletionNotesIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Completion Notes"
    static var description = IntentDescription("Appends to today's completion notes.")
    static var openAppWhenRun = false

    @Parameter(title: "Notes", description: "The text to add to the completion notes.")
    var notes: String

    @Parameter(title: "Overwrite existing notes", description: "If on, replaces what's already there.")
    var overwrite: Bool?

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .result(value: "No notes provided") }

        let (context, keyDate) = try await fetchContext(for: Date())
        let todayKey = DayEntry.makeDateKey(for: keyDate)
        let descriptor = FetchDescriptor<DayEntry>(predicate: #Predicate { $0.dateKey == todayKey })
        let entry = try context.fetch(descriptor).first ?? DayEntry(date: keyDate)
        if entry.modelContext == nil {
            context.insert(entry)
        }

        let shouldOverwrite = overwrite ?? false
        if shouldOverwrite || entry.completionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            entry.completionNote = trimmed
        } else {
            entry.completionNote = "\(entry.completionNote)\n\n\(trimmed)"
        }

        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result(value: "Completion notes updated")
    }
}

struct DailyThreeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetTasksIntent(),
            phrases: [
                "Get my tasks in \(.applicationName)",
                "Show today's tasks in \(.applicationName)",
                "What are my tasks in \(.applicationName)"
            ],
            shortTitle: "Get Tasks",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: AddTasksIntent(),
            phrases: [
                "Add tasks in \(.applicationName)",
                "Set today's tasks in \(.applicationName)",
                "Replace tasks in \(.applicationName)"
            ],
            shortTitle: "Add Tasks",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: GetProgressNotesIntent(),
            phrases: [
                "Get my progress notes in \(.applicationName)",
                "Show today's progress notes in \(.applicationName)",
                "What is my progress note in \(.applicationName)"
            ],
            shortTitle: "Progress Notes",
            systemImageName: "note.text"
        )
        AppShortcut(
            intent: AddProgressNotesIntent(),
            phrases: [
                "Add progress notes in \(.applicationName)",
                "Append progress notes in \(.applicationName)",
                "Log progress in \(.applicationName)"
            ],
            shortTitle: "Add Progress",
            systemImageName: "plus.bubble"
        )
        AppShortcut(
            intent: GetCompletionNotesIntent(),
            phrases: [
                "Get my completion notes in \(.applicationName)",
                "Show today's completion notes in \(.applicationName)",
                "What is my completion note in \(.applicationName)"
            ],
            shortTitle: "Completion Notes",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: AddCompletionNotesIntent(),
            phrases: [
                "Add completion notes in \(.applicationName)",
                "Append completion notes in \(.applicationName)",
                "Log completion in \(.applicationName)"
            ],
            shortTitle: "Add Completion",
            systemImageName: "plus.bubble"
        )
    }
}
