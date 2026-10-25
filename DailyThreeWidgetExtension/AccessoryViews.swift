//
//  AccessoryViews.swift
//  DailyThreeWidgetExtension
//
//  Lock Screen widgets (iOS and iPadOS). Moved unchanged from the original widget file.
//

import WidgetKit
import SwiftUI

#if os(iOS)
struct AccessoryCircularView: View {
    let snapshot: DailySnapshot

    var body: some View {
        ZStack {
            if hasAnyTasks {
                Gauge(value: Double(completedCount), in: 0...3) {
                    Text("Tasks")
                }
                .gaugeStyle(.accessoryCircular)
                .tint(.primary)
                Text("\(remainingCount)")
                    .font(.title2).bold()
                    .minimumScaleFactor(0.5)
            } else {
                Text("Add\ntasks")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var completedCount: Int {
        snapshot.completed.filter { $0 }.count
    }

    private var remainingCount: Int {
        max(0, 3 - completedCount)
    }

    private var hasAnyTasks: Bool {
        snapshot.tasks.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
#endif

#if os(iOS)
struct AccessoryRectangularView: View {
    let snapshot: DailySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if hasAnyTasks {
                ForEach(0..<3, id: \.self) { index in
                    HStack(spacing: 6) {
                        Image(systemName: isDone(at: index) ? "checkmark.circle.fill" : "circle")
                            .font(.caption2)
                            .foregroundStyle(isDone(at: index) ? .primary : .secondary)
                        Text(taskText(at: index))
                            .font(.caption2.bold())
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    if index < 2 {
                        Rectangle()
                            .fill(.secondary.opacity(0.35))
                            .frame(height: 1)
                    }
                }
            } else {
                Text("Add your tasks")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func taskText(at index: Int) -> String {
        let task = snapshot.tasks[safe: index] ?? ""
        return task.isEmpty ? "—" : task
    }

    private func isDone(at index: Int) -> Bool {
        snapshot.completed[safe: index] ?? false
    }

    private var hasAnyTasks: Bool {
        snapshot.tasks.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

struct AccessoryInlineView: View {
    let snapshot: DailySnapshot

    var body: some View {
        if hasAnyTasks {
            Text("Daily Three: \(completedCount)/3 done")
        } else {
            Text("Daily Three: add tasks")
        }
    }

    private var completedCount: Int {
        snapshot.completed.filter { $0 }.count
    }

    private var hasAnyTasks: Bool {
        snapshot.tasks.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
#endif
