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

    private var cardTitle: String {
        showCheckboxes ? "Today's Tasks" : "Tasks"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(cardTitle)
                .font(.system(.headline, design: .serif))

            ForEach(0..<3, id: \.self) { index in
                taskRowView(index: index)
            }
        }
        .padding(16)
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
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

    var body: some View {
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

    private func swapTasks(from: Int, to: Int) {
        let source = taskPair(for: from)
        let destination = taskPair(for: to)
        setTask(for: from, text: destination.text, done: destination.done)
        setTask(for: to, text: source.text, done: source.done)
    }

    private func taskPair(for index: Int) -> (text: String, done: Bool) {
        switch index {
        case 0:
            return (entry.taskOne, entry.taskOneDone)
        case 1:
            return (entry.taskTwo, entry.taskTwoDone)
        default:
            return (entry.taskThree, entry.taskThreeDone)
        }
    }

    private func setTask(for index: Int, text: String, done: Bool) {
        switch index {
        case 0:
            entry.taskOne = text
            entry.taskOneDone = done
        case 1:
            entry.taskTwo = text
            entry.taskTwoDone = done
        default:
            entry.taskThree = text
            entry.taskThreeDone = done
        }
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
