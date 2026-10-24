//
//  ArchiveView.swift
//  Daily Three
//

import SwiftUI

struct ArchiveView: View {
    let entries: [DayEntry]
    let theme: ThemePalette

    private var listContent: some View {
        List {
            ForEach(entries) { entry in
                NavigationLink {
                    ArchiveDetailView(entry: entry, theme: theme)
                } label: {
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
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            listContent
                .navigationTitle("Archive")
                .inlineNavigationBarTitle()
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Archive")
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                    }
                }
        }
        .tint(theme.accent)
        #else
        listContent
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

                TaskListCard(entry: entryBinding, theme: theme, isEditable: false)

                if !entry.progressNote.isEmpty {
                    NotesCard(title: "Progress", prompt: "", text: progressBinding, theme: theme, isEditable: false)
                }

                if !entry.completionNote.isEmpty {
                    NotesCard(title: "Completion", prompt: "", text: completionBinding, theme: theme, isEditable: false)
                }
            }
            .padding(16)
        }
        .background(theme.background)
        .navigationTitle("Details")
    }
}
