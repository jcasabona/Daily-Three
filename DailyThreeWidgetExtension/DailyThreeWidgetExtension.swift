//
//  DailyThreeWidgetExtension.swift
//  DailyThreeWidgetExtension
//
//  Created by Joe Casabona on 3/5/26.
//

import WidgetKit
import SwiftUI
import AppIntents
import SwiftData

struct DailySnapshot {
    let date: Date
    var tasks: [String]
    var completed: [Bool]
}

struct DailySnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: DailySnapshot
}

struct DailySnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailySnapshotEntry {
        DailySnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailySnapshotEntry) -> Void) {
        completion(DailySnapshotEntry(date: .now, snapshot: loadSnapshot() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailySnapshotEntry>) -> Void) {
        let entry = DailySnapshotEntry(date: .now, snapshot: loadSnapshot() ?? .placeholder)
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func loadSnapshot() -> DailySnapshot? {
        do {
            let container = try WidgetStoreConfiguration.makeContainer()
            let context = ModelContext(container)
            let todayKey = DayEntry.makeDateKey(for: Date())
            let descriptor = FetchDescriptor<DayEntry>(predicate: #Predicate { $0.dateKey == todayKey })
            if let entry = try context.fetch(descriptor).first {
                return DailySnapshot(date: entry.date,
                                     tasks: [entry.taskOne, entry.taskTwo, entry.taskThree],
                                     completed: [entry.taskOneDone, entry.taskTwoDone, entry.taskThreeDone])
            }
        } catch {
            return nil
        }
        return nil
    }
}

struct DailyThreeWidgetExtensionEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DailySnapshotProvider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(snapshot: entry.snapshot)
        case .systemMedium:
            MediumWidgetView(snapshot: entry.snapshot)
        case .accessoryCircular:
            AccessoryCircularView(snapshot: entry.snapshot)
        case .accessoryRectangular:
            AccessoryRectangularView(snapshot: entry.snapshot)
        case .accessoryInline:
            AccessoryInlineView(snapshot: entry.snapshot)
        default:
            MediumWidgetView(snapshot: entry.snapshot)
        }
    }
}

struct DailyThreeWidgetExtension: Widget {
    let kind: String = "DailyThreeWidgetExtension"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailySnapshotProvider()) { entry in
            DailyThreeWidgetExtensionEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Daily Three")
        .description("See today’s three tasks and progress.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

private struct SmallWidgetView: View {
    let snapshot: DailySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Three")
                .font(.headline)
            Text(snapshot.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            ProgressChip(completed: completedCount, total: 3)
        }
        .padding(12)
    }

    private var completedCount: Int {
        snapshot.completed.filter { $0 }.count
    }
}

private struct MediumWidgetView: View {
    let snapshot: DailySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Daily Three")
                    .font(.headline)
                Spacer()
                Text("\(completedCount)/3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(0..<3, id: \.self) { index in
                TaskLine(text: snapshot.tasks[safe: index] ?? "",
                         isDone: snapshot.completed[safe: index] ?? false,
                         intent: ToggleTaskIntent(index: index))
            }
        }
        .padding(12)
    }

    private var completedCount: Int {
        snapshot.completed.filter { $0 }.count
    }
}

private struct AccessoryCircularView: View {
    let snapshot: DailySnapshot

    var body: some View {
        ZStack {
            Gauge(value: Double(completedCount), in: 0...3) {
                Text("Daily")
            }
            .gaugeStyle(.accessoryCircular)
        }
    }

    private var completedCount: Int {
        snapshot.completed.filter { $0 }.count
    }
}

private struct AccessoryRectangularView: View {
    let snapshot: DailySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Daily Three")
                .font(.caption).bold()
            ForEach(0..<3, id: \.self) { index in
                TaskLine(text: snapshot.tasks[safe: index] ?? "",
                         isDone: snapshot.completed[safe: index] ?? false,
                         intent: nil)
            }
        }
    }
}

private struct AccessoryInlineView: View {
    let snapshot: DailySnapshot

    var body: some View {
        Text("Daily Three: \(completedCount)/3 done")
    }

    private var completedCount: Int {
        snapshot.completed.filter { $0 }.count
    }
}

private struct TaskLine: View {
    let text: String
    let isDone: Bool
    let intent: ToggleTaskIntent?

    var body: some View {
        if #available(iOS 17.0, *), let intent {
            Button(intent: intent) {
                TaskLineContent(text: text, isDone: isDone)
            }
            .buttonStyle(.plain)
        } else {
            TaskLineContent(text: text, isDone: isDone)
        }
    }
}

private struct TaskLineContent: View {
    let text: String
    let isDone: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.caption2)
            Text(text.isEmpty ? "–" : text)
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(isDone ? .primary : .secondary)
    }
}

private struct ProgressChip: View {
    let completed: Int
    let total: Int

    var body: some View {
        Text("\(completed)/\(total) done")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
    }
}

private extension DailySnapshot {
    static var placeholder: DailySnapshot {
        DailySnapshot(date: .now, tasks: ["Task 1", "Task 2", "Task 3"], completed: [false, true, false])
    }
}

struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task"

    @Parameter(title: "Task Index")
    var index: Int

    init() {}

    init(index: Int) {
        self.index = index
    }

    func perform() async throws -> some IntentResult {
        guard updateSharedStore() != nil else { return .result() }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    private func updateSharedStore() -> DailySnapshot? {
        do {
            let container = try WidgetStoreConfiguration.makeContainer()
            let context = ModelContext(container)
            let todayKey = DayEntry.makeDateKey(for: Date())
            let descriptor = FetchDescriptor<DayEntry>(predicate: #Predicate { $0.dateKey == todayKey })
            let entry = try context.fetch(descriptor).first ?? DayEntry(date: Date())
            if entry.modelContext == nil {
                context.insert(entry)
            }

            switch index {
            case 0:
                entry.taskOneDone.toggle()
            case 1:
                entry.taskTwoDone.toggle()
            case 2:
                entry.taskThreeDone.toggle()
            default:
                break
            }

            try context.save()

            return DailySnapshot(date: entry.date,
                                 tasks: [entry.taskOne, entry.taskTwo, entry.taskThree],
                                 completed: [entry.taskOneDone, entry.taskTwoDone, entry.taskThreeDone])
        } catch {
            return nil
        }
    }
}

#Preview(as: .systemSmall) {
    DailyThreeWidgetExtension()
} timeline: {
    DailySnapshotEntry(date: .now, snapshot: .placeholder)
}
