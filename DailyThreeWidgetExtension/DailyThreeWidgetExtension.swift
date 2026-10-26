//
//  DailyThreeWidgetExtension.swift
//  DailyThreeWidgetExtension
//
//  Today's Three: the three tasks with tappable check-offs, a progress ring, and optional journal notes.
//

import WidgetKit
import SwiftUI
import AppIntents

struct DailyThreeWidgetExtension: Widget {
    // Kept from the first version so widgets people already placed keep working.
    let kind: String = "DailyThreeWidgetExtension"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TodaysThreeConfiguration.self, provider: TodaysThreeProvider()) { entry in
            TodaysThreeEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetPalette(option: entry.snapshot.theme).background
                }
        }
        .configurationDisplayName("Today's Three")
        .description("Check off your three tasks, watch your progress, and jump into your journal.")
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        var families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
        if #available(iOS 27.0, macOS 27.0, *) {
            families.append(.systemExtraLargePortrait)
        }
        #if os(iOS)
        families += [.accessoryCircular, .accessoryRectangular, .accessoryInline]
        #endif
        return families
    }
}

// MARK: - Entry view

struct TodaysThreeEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodaysThreeEntry

    private var snapshot: DailySnapshot { entry.snapshot }
    private var palette: WidgetPalette { WidgetPalette(option: snapshot.theme) }

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        if #available(iOS 27.0, macOS 27.0, *), family == .systemExtraLargePortrait {
            TodayPortraitView(snapshot: snapshot, palette: palette, showJournal: entry.showJournal)
        } else {
            switch family {
            case .systemSmall:
                TodaySmallView(snapshot: snapshot, palette: palette)
            case .systemMedium:
                TodayMediumView(snapshot: snapshot, palette: palette)
            case .systemLarge:
                TodayLargeView(snapshot: snapshot, palette: palette, showJournal: entry.showJournal)
            case .systemExtraLarge:
                TodayExtraLargeView(snapshot: snapshot, palette: palette, showJournal: entry.showJournal)
            #if os(iOS)
            case .accessoryCircular:
                AccessoryCircularView(snapshot: snapshot)
            case .accessoryRectangular:
                AccessoryRectangularView(snapshot: snapshot)
            case .accessoryInline:
                AccessoryInlineView(snapshot: snapshot)
            #endif
            default:
                TodayMediumView(snapshot: snapshot, palette: palette)
            }
        }
    }
}

// MARK: - Pieces

private extension DailySnapshot {
    var dayText: String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    var shortDayText: String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

/// The ring with "1/3" in the middle.
private struct CountRing: View {
    let snapshot: DailySnapshot
    let palette: WidgetPalette
    var lineWidth: CGFloat = 8
    var numberSize: CGFloat = 22

    var body: some View {
        WidgetProgressRing(progress: snapshot.progress, palette: palette, lineWidth: lineWidth) {
            VStack(spacing: 0) {
                Text("\(snapshot.completedCount)/3")
                    .font(.system(size: numberSize, weight: .bold, design: .serif))
                    .minimumScaleFactor(0.7)
                if snapshot.isAllDone {
                    Image(systemName: "sparkles")
                        .font(.system(size: numberSize * 0.5, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(snapshot.completedCount) of 3 done")
    }
}

private struct TaskList: View {
    let snapshot: DailySnapshot
    let palette: WidgetPalette
    var checkSize: CGFloat = 20
    var fontSize: CGFloat = 14
    var lineLimit: Int = 2
    var spacing: CGFloat = 9

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(0..<3, id: \.self) { index in
                TaskRowButton(snapshot: snapshot, index: index, palette: palette,
                              checkSize: checkSize, fontSize: fontSize, lineLimit: lineLimit)
            }
        }
    }
}

private struct JournalPair: View {
    let snapshot: DailySnapshot
    let palette: WidgetPalette
    var lineLimit: Int = 3
    var stacked = false

    var body: some View {
        if stacked {
            VStack(spacing: 8) { blocks }
        } else {
            HStack(spacing: 8) { blocks }
        }
    }

    @ViewBuilder
    private var blocks: some View {
        JournalBlock(title: "Progress", text: snapshot.progressNote, section: "progress", palette: palette, lineLimit: lineLimit)
        JournalBlock(title: "End of Day", text: snapshot.completionNote, section: "completion", palette: palette, lineLimit: lineLimit)
    }
}

// MARK: - Small

struct TodaySmallView: View {
    let snapshot: DailySnapshot
    let palette: WidgetPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                WidgetTitle(text: "Today", size: 16)
                Spacer()
                if snapshot.hasAnyTasks {
                    Text("\(snapshot.completedCount)/3")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(palette.accent)
                        .widgetAccentable()
                }
            }

            if snapshot.hasAnyTasks {
                TaskList(snapshot: snapshot, palette: palette, checkSize: 18, fontSize: 12.5, lineLimit: 2, spacing: 7)
            } else {
                EmptyTasksView(palette: palette, compact: true)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Medium

struct TodayMediumView: View {
    let snapshot: DailySnapshot
    let palette: WidgetPalette

    var body: some View {
        if snapshot.hasAnyTasks {
            HStack(spacing: 16) {
                VStack(spacing: 6) {
                    CountRing(snapshot: snapshot, palette: palette, lineWidth: 9, numberSize: 22)
                        .frame(width: 88, height: 88)
                    Text(snapshot.shortDayText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    WidgetTitle(text: "Today's Three", size: 15)
                    TaskList(snapshot: snapshot, palette: palette, checkSize: 20, fontSize: 13.5, lineLimit: 1, spacing: 8)
                    Spacer(minLength: 0)
                }
            }
        } else {
            EmptyTasksView(palette: palette)
        }
    }
}

// MARK: - Large

struct TodayLargeView: View {
    let snapshot: DailySnapshot
    let palette: WidgetPalette
    let showJournal: Bool

    var body: some View {
        if snapshot.hasAnyTasks {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    CountRing(snapshot: snapshot, palette: palette, lineWidth: 8, numberSize: 19)
                        .frame(width: 70, height: 70)
                    VStack(alignment: .leading, spacing: 2) {
                        WidgetTitle(text: "Today's Three", size: 20)
                        Text(snapshot.dayText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                TaskList(snapshot: snapshot, palette: palette, checkSize: 24, fontSize: 15, lineLimit: 2, spacing: 12)

                if showJournal {
                    JournalPair(snapshot: snapshot, palette: palette, lineLimit: 4)
                        .frame(maxHeight: .infinity)
                } else {
                    Spacer(minLength: 0)
                }
            }
        } else {
            EmptyTasksView(palette: palette)
        }
    }
}

// MARK: - Extra large (iPad and Mac)

struct TodayExtraLargeView: View {
    let snapshot: DailySnapshot
    let palette: WidgetPalette
    let showJournal: Bool

    var body: some View {
        if snapshot.hasAnyTasks {
            HStack(spacing: 26) {
                VStack(spacing: 10) {
                    CountRing(snapshot: snapshot, palette: palette, lineWidth: 14, numberSize: 38)
                        .frame(width: 170, height: 170)
                    Text(snapshot.dayText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 18) {
                    WidgetTitle(text: "Today's Three", size: 26)
                    TaskList(snapshot: snapshot, palette: palette, checkSize: 30, fontSize: 19, lineLimit: 2, spacing: 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                if showJournal {
                    JournalPair(snapshot: snapshot, palette: palette, lineLimit: 8, stacked: true)
                        .frame(width: 250)
                }
            }
        } else {
            EmptyTasksView(palette: palette)
        }
    }
}

// MARK: - Extra large portrait (iPhone Duo)

@available(iOS 27.0, macOS 27.0, *)
struct TodayPortraitView: View {
    let snapshot: DailySnapshot
    let palette: WidgetPalette
    let showJournal: Bool

    var body: some View {
        if snapshot.hasAnyTasks {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    CountRing(snapshot: snapshot, palette: palette, lineWidth: 11, numberSize: 26)
                        .frame(width: 110, height: 110)
                    VStack(alignment: .leading, spacing: 3) {
                        WidgetTitle(text: "Today's Three", size: 22)
                        Text(snapshot.dayText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                TaskList(snapshot: snapshot, palette: palette, checkSize: 26, fontSize: 16, lineLimit: 2, spacing: 14)

                if showJournal {
                    JournalPair(snapshot: snapshot, palette: palette, lineLimit: 6, stacked: true)
                        .frame(maxHeight: .infinity)
                } else {
                    Spacer(minLength: 0)
                }
            }
        } else {
            EmptyTasksView(palette: palette)
        }
    }
}

// MARK: - Previews

#Preview("Today's Three", as: .systemSmall) {
    DailyThreeWidgetExtension()
} timeline: {
    TodaysThreeEntry(date: .now, snapshot: .sample, showJournal: true)
    TodaysThreeEntry(date: .now, snapshot: DailySnapshot.sample.with(theme: .ocean), showJournal: true)
    TodaysThreeEntry(date: .now, snapshot: DailySnapshot.sample.with(theme: .sunrise), showJournal: true)
    TodaysThreeEntry(date: .now, snapshot: DailySnapshot.sample.with(theme: .forest), showJournal: true)
    TodaysThreeEntry(date: .now, snapshot: .empty(theme: .graphite), showJournal: true)
}
