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
import Foundation

#if os(iOS)
import UIKit
#endif

struct DailySnapshot {
    let date: Date
    var tasks: [String]
    var completed: [Bool]
    var theme: ThemeOption
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
                let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first
                let theme = settings?.theme ?? .sunrise
                return DailySnapshot(date: entry.date,
                                     tasks: [entry.taskOne, entry.taskTwo, entry.taskThree],
                                     completed: [entry.taskOneDone, entry.taskTwoDone, entry.taskThreeDone],
                                     theme: theme)
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
        case .systemLarge:
            LargeWidgetView(snapshot: entry.snapshot)
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
            .systemLarge,
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
        VStack(alignment: .leading, spacing: 10) {
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
        .padding(14)
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

private struct LargeWidgetView: View {
    let snapshot: DailySnapshot

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Daily Three")
                    .font(.headline)
                Spacer()
                Text(snapshot.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            ProgressRing(progress: progress, tint: themeAccentColor(snapshot.theme))
                .frame(height: 165)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    TaskLine(text: snapshot.tasks[safe: index] ?? "",
                             isDone: snapshot.completed[safe: index] ?? false,
                             intent: ToggleTaskIntent(index: index))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }

    private var progress: Double {
        guard !snapshot.completed.isEmpty else { return 0 }
        let completed = snapshot.completed.filter { $0 }.count
        return Double(completed) / 3.0
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
        HStack(spacing: 10) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.title3)
            Text(text.isEmpty ? "–" : text)
                .font(.callout)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
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

private struct ProgressRing: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.25), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(percentText)
                .font(.title2)
        }
        .accessibilityLabel("Completion")
        .accessibilityValue(percentText)
    }

    private var percentText: String {
        let value = Int(round(progress * 100))
        return "\(value)%"
    }
}

private func themeAccentColor(_ option: ThemeOption) -> Color {
    #if os(iOS)
    return Color(uiColor: UIColor { trait in
        let isDark = trait.userInterfaceStyle == .dark
        switch option {
        case .sunrise:
            return isDark
            ? UIColor(red: 0.99, green: 0.67, blue: 0.44, alpha: 1)
            : UIColor(red: 0.95, green: 0.48, blue: 0.30, alpha: 1)
        case .ocean:
            return isDark
            ? UIColor(red: 0.46, green: 0.73, blue: 0.92, alpha: 1)
            : UIColor(red: 0.16, green: 0.47, blue: 0.78, alpha: 1)
        case .forest:
            return isDark
            ? UIColor(red: 0.50, green: 0.78, blue: 0.60, alpha: 1)
            : UIColor(red: 0.18, green: 0.54, blue: 0.34, alpha: 1)
        case .graphite:
            return isDark
            ? UIColor(red: 0.72, green: 0.73, blue: 0.76, alpha: 1)
            : UIColor(red: 0.32, green: 0.33, blue: 0.36, alpha: 1)
        }
    })
    #else
    return .primary
    #endif
}

private extension DailySnapshot {
    static var placeholder: DailySnapshot {
        DailySnapshot(date: .now,
                      tasks: ["Task 1", "Task 2", "Task 3"],
                      completed: [false, true, false],
                      theme: .sunrise)
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

            let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first
            let theme = settings?.theme ?? .sunrise
            return DailySnapshot(date: entry.date,
                                 tasks: [entry.taskOne, entry.taskTwo, entry.taskThree],
                                 completed: [entry.taskOneDone, entry.taskTwoDone, entry.taskThreeDone],
                                 theme: theme)
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
