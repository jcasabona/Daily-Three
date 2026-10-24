//
//  TaskViews.swift
//  Daily Three
//

import SwiftUI
import UniformTypeIdentifiers

struct TaskListCard: View {
    @Binding var entry: DayEntry
    let theme: ThemePalette
    var isEditable: Bool = true
    var showCheckboxes: Bool = true
    var showDragHandles: Bool = true
    @State private var draggedIndex: Int?
    @Environment(\.surfaceStyle) private var style

    private var cardTitle: String {
        showCheckboxes ? "Today's Tasks" : "Tasks"
    }

    var body: some View {
        if style == .flat {
            VStack(alignment: .leading, spacing: 4) {
                FlatSectionHeader(title: cardTitle, theme: theme)
                    .padding(.bottom, 4)

                ForEach(0..<3, id: \.self) { index in
                    taskRowView(index: index)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(cardTitle)
                    .font(.system(.headline, design: .serif))

                ForEach(0..<3, id: \.self) { index in
                    taskRowView(index: index)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func taskRowView(index: Int) -> some View {
        let row = TaskRow(title: taskTitle(for: index),
                          text: textBinding(for: index),
                          isDone: doneBinding(for: index),
                          isEditable: isEditable,
                          theme: theme,
                          showsDragHandle: showDragHandles,
                          showCheckbox: showCheckboxes)
            .contentShape(Rectangle())

        if showDragHandles {
            row
                .onDrag {
                    draggedIndex = index
                    return NSItemProvider(item: nil, typeIdentifier: UTType.data.identifier)
                }
                .onDrop(of: [UTType.data], delegate: TaskDropDelegate(destinationIndex: index,
                                                                     draggedIndex: $draggedIndex,
                                                                     entry: $entry))
        } else {
            row
        }
    }

    private func taskTitle(for index: Int) -> String {
        switch index {
        case 0: return "Task 1"
        case 1: return "Task 2"
        default: return "Task 3"
        }
    }

    private func textBinding(for index: Int) -> Binding<String> {
        Binding(get: { taskText(for: index) }, set: { setTaskText(for: index, value: $0) })
    }

    private func doneBinding(for index: Int) -> Binding<Bool> {
        Binding(get: { taskDone(for: index) }, set: { setTaskDone(for: index, value: $0) })
    }

    private func taskText(for index: Int) -> String {
        switch index {
        case 0: return entry.taskOne
        case 1: return entry.taskTwo
        default: return entry.taskThree
        }
    }

    private func taskDone(for index: Int) -> Bool {
        switch index {
        case 0: return entry.taskOneDone
        case 1: return entry.taskTwoDone
        default: return entry.taskThreeDone
        }
    }

    private func setTaskText(for index: Int, value: String) {
        switch index {
        case 0: entry.taskOne = value
        case 1: entry.taskTwo = value
        default: entry.taskThree = value
        }
    }

    private func setTaskDone(for index: Int, value: Bool) {
        switch index {
        case 0: entry.taskOneDone = value
        case 1: entry.taskTwoDone = value
        default: entry.taskThreeDone = value
        }
    }
}

private struct TaskRow: View {
    let title: String
    @Binding var text: String
    @Binding var isDone: Bool
    let isEditable: Bool
    let theme: ThemePalette
    var showsDragHandle: Bool = false
    var showCheckbox: Bool = true
    @Environment(\.surfaceStyle) private var style

    var body: some View {
        if style == .flat {
            flatBody
        } else {
            cardBody
        }
    }

    /// Plain list row: small square checkbox and text, no box around it.
    private var flatBody: some View {
        HStack(spacing: 10) {
            if showCheckbox {
                Button(action: { isDone.toggle() }) {
                    Image(systemName: isDone ? "checkmark.square.fill" : "square")
                        .font(.system(size: 17))
                        .foregroundStyle(isDone ? theme.accent : theme.muted)
                }
                .buttonStyle(.plain)
                .disabled(!isEditable)
            }

            if isEditable {
                TextField(title, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundStyle(isDone ? .secondary : .primary)
            } else {
                Text(text.isEmpty ? title : text)
                    .font(.system(size: 16))
                    .foregroundStyle(text.isEmpty || isDone ? .secondary : .primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 7)
        .overlay(alignment: .trailing) {
            if showsDragHandle {
                Image(systemName: "line.3.horizontal")
                    .font(.subheadline)
                    .foregroundStyle(theme.muted.opacity(0.6))
            }
        }
    }

    private var cardBody: some View {
        HStack(spacing: 12) {
            if showCheckbox {
                Button(action: { isDone.toggle() }) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isDone ? theme.accent : theme.muted)
                }
                .buttonStyle(.plain)
                .disabled(!isEditable)
            }

            if isEditable {
                TextField(title, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .regular, design: .serif))
            } else {
                Text(text.isEmpty ? title : text)
                    .foregroundStyle(text.isEmpty ? .secondary : .primary)
                    .font(.system(size: 17, weight: .regular, design: .serif))
            }
        }
        // Read-only rows are plain Text and would otherwise hug their content.
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(theme.field)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .overlay(alignment: .trailing) {
            if showsDragHandle {
                Image(systemName: "line.3.horizontal")
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .padding(.trailing, 8)
            }
        }
    }
}

private struct TaskDropDelegate: DropDelegate {
    let destinationIndex: Int
    @Binding var draggedIndex: Int?
    @Binding var entry: DayEntry

    func dropEntered(info: DropInfo) {
        guard let draggedIndex, draggedIndex != destinationIndex else { return }
        swapTasks(from: draggedIndex, to: destinationIndex)
        self.draggedIndex = destinationIndex
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedIndex = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    /// Swaps whole slots, so a task keeps its completion and Todoist link when it moves.
    private func swapTasks(from: Int, to: Int) {
        entry.swapSlots(from, to)
    }
}

struct TaskEditorRow: View {
    let title: String
    @Binding var text: String
    let theme: ThemePalette

    var body: some View {
        TextField(title, text: $text)
            .textFieldStyle(.plain)
            .padding(12)
            .background(theme.field)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
    }
}
