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
    /// A note the app should scroll to and focus, requested by a widget's Journal button.
    @Binding var focusedJournal: JournalSection?
    let onSnapshotChange: () -> Void
    let onTasksSetChange: () -> Void
    @State private var lastHasAllTasksSet: Bool?
    @State private var availableWidth: CGFloat = 0
    @Environment(\.surfaceStyle) private var style
    @Environment(\.usesSidebar) private var usesSidebar
    @Environment(\.foldPosture) private var posture
    /// The note the keyboard is up for, if any. In laptop mode that note takes over the screen.
    @State private var activeNote: JournalSection?

    private var sectionSpacing: CGFloat { style == .flat ? 28 : 16 }
    private var horizontalPadding: CGFloat {
        guard style == .flat else { return 16 }
        // Narrow screens (iPhone, split view) get tighter margins than a Mac window or full iPad.
        return availableWidth > 0 && availableWidth < Self.twoColumnMinWidth ? 20 : 36
    }

    /// Width at which Today puts tasks and notes side by side instead of stacking them.
    private static let twoColumnMinWidth: CGFloat = 640
    /// Keeps a single column readable when the window is wide but there is no second column.
    private static let singleColumnMaxWidth: CGFloat = 640

    private var usesTwoColumns: Bool {
        editingMode == .today && availableWidth >= Self.twoColumnMinWidth
    }

    private var subtitle: String {
        editingMode == .today ? "" : "Plan ahead"
    }

    private var showCheckboxes: Bool {
        editingMode == .today
    }

    private var showDragHandles: Bool {
        editingMode == .today
    }

    private var planningSection: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            DateSelectorBar(dates: selectableDates, selectedDate: $selectedDate, theme: theme)

            HeaderCard(title: formattedDate(entry.date), subtitle: subtitle, theme: theme)

            TaskListCard(entry: $entry, theme: theme, isEditable: editingMode != .readOnly, showCheckboxes: showCheckboxes, showDragHandles: showDragHandles)
        }
    }

    /// Laptop mode: the top half is tasks, the bottom half is the journal.
    private var isLaptop: Bool { posture == .laptop && editingMode == .today }

    private func isActive(_ section: JournalSection) -> Bool { isLaptop && activeNote == section }
    private func isHidden(_ section: JournalSection) -> Bool { isLaptop && activeNote != nil && activeNote != section }

    private func noteFocusChanged(_ section: JournalSection, _ focused: Bool) {
        if focused {
            activeNote = section
        } else if activeNote == section {
            activeNote = nil
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            NotesCard(title: "Checking in throughout the day", prompt: "How are you progressing on your tasks?", text: $entry.progressNote, theme: theme,
                      focusRequested: focusedJournal == .progress, onFocusHandled: { focusedJournal = nil },
                      onFocusChange: { noteFocusChanged(.progress, $0) }, expands: isActive(.progress))
                .id(JournalSection.progress)
                .frame(maxHeight: isHidden(.progress) ? 0 : (isActive(.progress) ? .infinity : nil))
                .opacity(isHidden(.progress) ? 0 : 1)
                .clipped()

            NotesCard(title: "End of the day check-in", prompt: "Did you complete your tasks?", text: $entry.completionNote, theme: theme,
                      focusRequested: focusedJournal == .completion, onFocusHandled: { focusedJournal = nil },
                      onFocusChange: { noteFocusChanged(.completion, $0) }, expands: isActive(.completion))
                .id(JournalSection.completion)
                .frame(maxHeight: isHidden(.completion) ? 0 : (isActive(.completion) ? .infinity : nil))
                .opacity(isHidden(.completion) ? 0 : 1)
                .clipped()
        }
    }

    /// Half-folded like a laptop: tasks above the crease, journal below. With the keyboard up, the note being
    /// typed in takes the whole screen. Both halves stay in the view tree so the text field keeps its focus.
    private var laptopContent: some View {
        let keyboardUp = activeNote != nil
        return VStack(spacing: 0) {
            ScrollView {
                planningSection
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 12)
            }
            .frame(maxHeight: keyboardUp ? 0 : .infinity)
            .opacity(keyboardUp ? 0 : 1)
            .clipped()

            Divider()
                .opacity(keyboardUp ? 0 : 1)

            notesSection
                .padding(.horizontal, horizontalPadding)
                .padding(.top, keyboardUp ? 8 : 12)
                .padding(.bottom, 8)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .animation(.easeInOut(duration: 0.25), value: activeNote)
    }

    @ViewBuilder
    private var scrollContent: some View {
        if isLaptop {
            laptopContent
        } else {
            scrollingContent
        }
    }

    private var scrollingContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Group {
                    if usesTwoColumns {
                        HStack(alignment: .top, spacing: sectionSpacing + 8) {
                            planningSection
                                .frame(maxWidth: .infinity)
                            notesSection
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: sectionSpacing) {
                            planningSection

                            if editingMode == .today {
                                notesSection
                            }
                        }
                        .frame(maxWidth: Self.singleColumnMaxWidth)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
            .onChange(of: focusedJournal) { _, section in
                guard let section else { return }
                withAnimation { proxy.scrollTo(section, anchor: .center) }
            }
        }
    }

    #if os(iOS)
    @ViewBuilder
    private var viewContainer: some View {
        if usesSidebar {
            scrollContent
                .padding(.top, 24)
                .background(theme.background)
        } else {
            navigationContainer
        }
    }

    private var navigationContainer: some View {
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
            .padding(.top, 24)
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
