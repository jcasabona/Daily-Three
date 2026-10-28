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
    @Environment(\.usesSidebar) private var usesSidebar
    @State private var paneWidth: CGFloat = 0

    /// The list and the day page sit side by side only when the pane is at least this wide.
    private static let sideBySideMinWidth: CGFloat = 700

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
        .modifier(ArchiveListStyle(flat: usesSidebar, theme: theme))
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
        if usesSidebar {
            // Already inside the app's sidebar, so a second split view would nest. Lay the panes out side by side
            // when there's room, and otherwise show the list, then the day page with a Back button.
            Group {
                if paneWidth >= Self.sideBySideMinWidth {
                    HStack(spacing: 0) {
                        listContent
                            .frame(width: 320)
                        Divider()
                        detailContent
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    stackedLayout
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { paneWidth = $0 }
            .tint(theme.accent)
        } else {
            phoneLayout
        }
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

    #if os(iOS)
    /// One pane at a time: the day list at full width, then the chosen day with a way back.
    @ViewBuilder
    private var stackedLayout: some View {
        if let selectedEntry {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        selectedID = nil
                    } label: {
                        Label("Archive", systemImage: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                ArchiveDetailView(entry: selectedEntry, theme: theme)
            }
            .background(theme.background)
        } else {
            listContent
        }
    }

    // Collapses to list → push on narrow screens and shows both panes when there is room.
    private var phoneLayout: some View {
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
    }
    #endif

    private func summary(for entry: DayEntry) -> String {
        let completed = [entry.taskOneDone, entry.taskTwoDone, entry.taskThreeDone].filter { $0 }.count
        return "\(completed) of 3 completed"
    }
}

private struct ArchiveDetailView: View {
    @Bindable var entry: DayEntry
    let theme: ThemePalette
    @Environment(\.usesSidebar) private var usesSidebar

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
        #if os(iOS)
        .toolbar(usesSidebar ? .hidden : .automatic, for: .navigationBar)
        #endif
    }
}

#if os(iOS)
/// The phone keeps the grouped list; the iPad sidebar layout uses a plain one to match the Mac.
private struct ArchiveListStyle: ViewModifier {
    let flat: Bool
    let theme: ThemePalette

    func body(content: Content) -> some View {
        if flat {
            content.listStyle(.inset)
                .scrollContentBackground(.hidden)
                .background(theme.background)
        } else {
            content.listStyle(.insetGrouped)
        }
    }
}
#endif
