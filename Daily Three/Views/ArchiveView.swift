//
//  ArchiveView.swift
//  Daily Three
//

import SwiftUI
import SwiftData

struct ArchiveView: View {
    let entries: [DayEntry]
    let theme: ThemePalette
    @State private var selectedID: DayEntry.ID?

    private var selectedEntry: DayEntry? {
        entries.first { $0.id == selectedID }
    }

    private var listContent: some View {
        List(selection: $selectedID) {
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.date.formatted(date: .complete, time: .omitted))
                        .font(.headline)
                    Text(summary(for: entry))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }

    @ViewBuilder
    private var detailContent: some View {
        if let selectedEntry {
            ArchiveDetailView(entry: selectedEntry, theme: theme)
        } else {
            ContentUnavailableView("Select a Day", systemImage: "calendar", description: Text("Pick a day to see its tasks and notes."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
        }
    }

    var body: some View {
        #if os(iOS)
        // Collapses to list → push on narrow screens and shows both panes when there is room.
        NavigationSplitView {
            listContent
                .navigationTitle("Archive")
                .inlineNavigationBarTitle()
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Archive")
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                    }
                }
        } detail: {
            detailContent
        }
        .tint(theme.accent)
        #else
        HSplitView {
            listContent
                .frame(minWidth: 240, idealWidth: 300, maxWidth: 420)
            detailContent
                .frame(minWidth: 320, maxWidth: .infinity)
        }
        .tint(theme.accent)
        #endif
    }

    private func summary(for entry: DayEntry) -> String {
        let completed = [entry.taskOneDone, entry.taskTwoDone, entry.taskThreeDone].filter { $0 }.count
        return "\(completed) of 3 completed"
    }
}

private struct ArchiveDetailView: View {
    @Bindable var entry: DayEntry
    let theme: ThemePalette

    var body: some View {
        let entryBinding = Binding<DayEntry>(get: { entry }, set: { _ in })
        let progressBinding = Binding<String>(get: { entry.progressNote }, set: { _ in })
        let completionBinding = Binding<String>(get: { entry.completionNote }, set: { _ in })
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderCard(title: entry.date.formatted(date: .complete, time: .omitted), subtitle: "Snapshot", theme: theme)

                TaskListCard(entry: entryBinding, theme: theme, isEditable: false, showDragHandles: false)

                if !entry.progressNote.isEmpty {
                    NotesCard(title: "Checking in throughout the day", prompt: "", text: progressBinding, theme: theme, isEditable: false)
                }

                if !entry.completionNote.isEmpty {
                    NotesCard(title: "End of the day check-in", prompt: "", text: completionBinding, theme: theme, isEditable: false)
                }
            }
            .padding(16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle("Details")
    }
}
