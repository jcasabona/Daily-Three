//
//  TodoistTaskPicker.swift
//  Daily Three
//
//  Sheet for choosing a Todoist task to link to one of the three slots.
//

import SwiftUI

/// Identifies which slot a picker sheet is for, so it can be presented with `.sheet(item:)`.
struct TodoistPickerTarget: Identifiable {
    let slot: Int
    var id: Int { slot }
}

struct TodoistTaskPicker: View {
    let theme: ThemePalette
    /// Tasks already linked on this day, which can't be picked twice.
    let excludedIDs: Set<String>
    let onPick: (TodoistTask) -> Void

    @Environment(TodoistSyncService.self) private var todoist
    @Environment(\.dismiss) private var dismiss

    private enum Scope: String, CaseIterable, Identifiable {
        case today = "Today"
        case all = "All"
        var id: String { rawValue }
        /// Todoist filter query. `nil` lists every active task.
        var filter: String? { self == .today ? "today | overdue" : nil }
    }

    @State private var scope: Scope = .today
    @State private var tasks: [TodoistTask] = []
    @State private var query = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var visibleTasks: [TodoistTask] {
        tasks.filter { task in
            !excludedIDs.contains(task.id)
                && (query.trimmed.isEmpty || task.content.localizedCaseInsensitiveContains(query.trimmed))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Show", selection: $scope) {
                        ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    if isLoading && tasks.isEmpty {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    } else if visibleTasks.isEmpty {
                        ContentUnavailableView(query.isEmpty ? "No tasks" : "No matches",
                                               systemImage: "checklist",
                                               description: Text(scope == .today ? "Nothing is due today. Try All." : "No active tasks found."))
                    } else {
                        ForEach(visibleTasks) { task in
                            Button {
                                onPick(task)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.content).foregroundStyle(.primary)
                                    if let due = task.due?.string, !due.isEmpty {
                                        Text(due).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search tasks")
            .navigationTitle("Todoist")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task(id: scope) { await load() }
        }
        .tint(theme.accent)
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            tasks = try await todoist.pickableTasks(filter: scope.filter)
        } catch {
            tasks = []
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
