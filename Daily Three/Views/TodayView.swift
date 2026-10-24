//
//  TodayView.swift
//  Daily Three
//

import SwiftUI

struct TodayView: View {
    @Binding var entry: DayEntry
    let theme: ThemePalette
    let editingMode: DayEditingMode
    let selectableDates: [Date]
    @Binding var selectedDate: Date
    let onSnapshotChange: () -> Void
    let onTasksSetChange: () -> Void
    @State private var lastHasAllTasksSet: Bool?

    private var subtitle: String {
        editingMode == .today ? "Your three tasks" : "Plan ahead"
    }

    private var showCheckboxes: Bool {
        editingMode == .today
    }

    private var showDragHandles: Bool {
        editingMode == .today
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DateSelectorBar(dates: selectableDates, selectedDate: $selectedDate, theme: theme)

                HeaderCard(title: formattedDate(entry.date), subtitle: subtitle, theme: theme)

                TaskListCard(entry: $entry, theme: theme, isEditable: editingMode != .readOnly, showCheckboxes: showCheckboxes, showDragHandles: showDragHandles)

                if editingMode == .today {
                    NotesCard(title: "Progress", prompt: "How are you progressing on your tasks?", text: $entry.progressNote, theme: theme)

                    NotesCard(title: "Completion", prompt: "Did you complete your tasks?", text: $entry.completionNote, theme: theme)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    #if os(iOS)
    private var viewContainer: some View {
        NavigationStack {
            scrollContent
                .background(theme.background)
                .navigationTitle("Daily Three")
                .inlineNavigationBarTitle()
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Daily Three")
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                    }
                }
        }
    }
    #else
    private var viewContainer: some View {
        scrollContent
            .padding(.top, 12)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
            .background(theme.background)
    }
    #endif

    var body: some View {
        viewContainer
        .onChange(of: entry.taskOne) { _, _ in
            onSnapshotChange()
            if editingMode == .today { notifyTasksSetChangeIfNeeded() }
        }
        .onChange(of: entry.taskTwo) { _, _ in
            onSnapshotChange()
            if editingMode == .today { notifyTasksSetChangeIfNeeded() }
        }
        .onChange(of: entry.taskThree) { _, _ in
            onSnapshotChange()
            if editingMode == .today { notifyTasksSetChangeIfNeeded() }
        }
        .onChange(of: entry.taskOneDone) { _, _ in
            if editingMode == .today { onSnapshotChange() }
        }
        .onChange(of: entry.taskTwoDone) { _, _ in
            if editingMode == .today { onSnapshotChange() }
        }
        .onChange(of: entry.taskThreeDone) { _, _ in
            if editingMode == .today { onSnapshotChange() }
        }
        .onChange(of: entry.progressNote) { _, _ in
            if editingMode == .today { onSnapshotChange() }
        }
        .onChange(of: entry.completionNote) { _, _ in
            if editingMode == .today { onSnapshotChange() }
        }
        .onAppear {
            lastHasAllTasksSet = entry.hasAllTasksSet
        }
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .complete, time: .omitted)
    }

    private func notifyTasksSetChangeIfNeeded() {
        let current = entry.hasAllTasksSet
        guard lastHasAllTasksSet != current else { return }
        lastHasAllTasksSet = current
        onTasksSetChange()
    }
}
