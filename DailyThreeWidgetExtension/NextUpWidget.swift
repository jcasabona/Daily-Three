//
//  NextUpWidget.swift
//  DailyThreeWidgetExtension
//
//  Next Up: the next unfinished task, a big check button, and a shortcut to the journal.
//

import WidgetKit
import SwiftUI
import AppIntents

struct NextUpWidget: Widget {
    let kind: String = "DailyThreeNextUpWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            NextUpEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetPalette(option: entry.snapshot.theme).background
                }
        }
        .configurationDisplayName("Next Up")
        .description("Your next task, with a big check button and a shortcut to your journal.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NextUpEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var snapshot: DailySnapshot { entry.snapshot }
    private var palette: WidgetPalette { WidgetPalette(option: snapshot.theme) }

    var body: some View {
        if !snapshot.hasAnyTasks {
            EmptyTasksView(palette: palette, compact: family == .systemSmall)
        } else if family == .systemMedium {
            NextUpMediumView(snapshot: snapshot, palette: palette)
        } else {
            NextUpSmallView(snapshot: snapshot, palette: palette)
        }
    }
}

/// The big check button.
private struct CheckNextButton: View {
    let palette: WidgetPalette
    var compact = false

    var body: some View {
        Button(intent: CompleteNextTaskIntent()) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: compact ? 14 : 20, weight: .bold))
                Text("Done")
                    .font(.system(size: compact ? 14 : 18, weight: .bold))
            }
            .foregroundStyle(palette.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 9 : 14)
            .background(palette.accent, in: Capsule())
            .widgetAccentable()
        }
        .buttonStyle(.plain)
    }
}

/// Opens the app at the Progress note, or the Completion note once everything's done.
private struct JournalButton: View {
    let palette: WidgetPalette
    let section: String
    var compact = false

    var body: some View {
        Link(destination: URL(string: "dailythree://journal?section=\(section)")!) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: compact ? 13 : 17, weight: .semibold))
                Text("Journal")
                    .font(.system(size: compact ? 13 : 16, weight: .semibold))
            }
            .foregroundStyle(palette.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 8 : 12)
            .background(palette.panel, in: Capsule())
        }
    }
}

private struct NextUpSmallView: View {
    let snapshot: DailySnapshot
    let palette: WidgetPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.isAllDone ? "ALL DONE" : "NEXT UP")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(palette.accent)
                Spacer()
                Text("\(snapshot.completedCount)/3")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            if let index = snapshot.nextTaskIndex {
                Text(snapshot.task(at: index))
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                CheckNextButton(palette: palette, compact: true)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(palette.accent)
                Text("Nice work. Everything's done.")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .lineLimit(3)
                Spacer(minLength: 0)
                JournalButton(palette: palette, section: "completion", compact: true)
            }
        }
    }
}

private struct NextUpMediumView: View {
    let snapshot: DailySnapshot
    let palette: WidgetPalette

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.isAllDone ? "ALL DONE" : "NEXT UP · TASK \((snapshot.nextTaskIndex ?? 0) + 1) OF 3")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(palette.accent)

                if let index = snapshot.nextTaskIndex {
                    Text(snapshot.task(at: index))
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .lineLimit(4)
                        .minimumScaleFactor(0.8)
                } else {
                    Text("Nice work. Everything's done for today.")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
                Text("\(snapshot.completedCount) of 3 done")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                if snapshot.nextTaskIndex != nil {
                    CheckNextButton(palette: palette)
                }
                JournalButton(palette: palette, section: snapshot.isAllDone ? "completion" : "progress")
            }
            .frame(width: 128)
        }
    }
}

#Preview("Next Up", as: .systemMedium) {
    NextUpWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample)
    SnapshotEntry(date: .now, snapshot: DailySnapshot.sample.with(theme: .ocean))
    SnapshotEntry(date: .now, snapshot: DailySnapshot(date: .now, tasks: ["A", "B", "C"], completed: [true, true, true], theme: .sunrise))
}
