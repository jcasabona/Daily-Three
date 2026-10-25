//
//  JournalWidget.swift
//  DailyThreeWidgetExtension
//
//  Journal: today's Progress and Completion notes. Tapping a note opens the app to write it.
//

import WidgetKit
import SwiftUI

struct JournalWidget: Widget {
    let kind: String = "DailyThreeJournalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            JournalEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetPalette(option: entry.snapshot.theme).background
                }
        }
        .configurationDisplayName("Journal")
        .description("Your Progress and Completion notes for today. Tap one to write.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct JournalEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var snapshot: DailySnapshot { entry.snapshot }
    private var palette: WidgetPalette { WidgetPalette(option: snapshot.theme) }
    private var isLarge: Bool { family == .systemLarge }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                WidgetTitle(text: "Journal", size: isLarge ? 20 : 15)
                Spacer()
                Text(snapshot.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if isLarge {
                VStack(spacing: 10) { blocks }
            } else {
                HStack(spacing: 10) { blocks }
            }
        }
    }

    @ViewBuilder
    private var blocks: some View {
        JournalBlock(title: "Progress", text: snapshot.progressNote, section: "progress", palette: palette, lineLimit: isLarge ? 9 : 5)
        JournalBlock(title: "Completion", text: snapshot.completionNote, section: "completion", palette: palette, lineLimit: isLarge ? 9 : 5)
    }
}

#Preview("Journal", as: .systemMedium) {
    JournalWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample)
    SnapshotEntry(date: .now, snapshot: DailySnapshot.sample.with(theme: .forest))
    SnapshotEntry(date: .now, snapshot: .empty(theme: .graphite))
}
