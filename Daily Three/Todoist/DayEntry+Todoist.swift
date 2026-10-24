//
//  DayEntry+Todoist.swift
//  Daily Three
//
//  Slot-indexed access to a day's tasks and their Todoist links.
//

import Foundation

extension DayEntry {
    static let slotCount = 3

    func text(in slot: Int) -> String {
        switch slot {
        case 0: return taskOne
        case 1: return taskTwo
        default: return taskThree
        }
    }

    func isDone(in slot: Int) -> Bool {
        switch slot {
        case 0: return taskOneDone
        case 1: return taskTwoDone
        default: return taskThreeDone
        }
    }

    func todoistLink(in slot: Int) -> TodoistLink {
        switch slot {
        case 0: return TodoistLink(taskID: todoistIDOne, syncedContent: todoistSyncedContentOne, syncedDone: todoistSyncedDoneOne)
        case 1: return TodoistLink(taskID: todoistIDTwo, syncedContent: todoistSyncedContentTwo, syncedDone: todoistSyncedDoneTwo)
        default: return TodoistLink(taskID: todoistIDThree, syncedContent: todoistSyncedContentThree, syncedDone: todoistSyncedDoneThree)
        }
    }

    func slotState(_ slot: Int) -> TodoistSlotState {
        TodoistSlotState(text: text(in: slot), done: isDone(in: slot), link: todoistLink(in: slot))
    }

    /// Writes a slot's text, completion and Todoist link in one go.
    func apply(_ state: TodoistSlotState, to slot: Int) {
        switch slot {
        case 0:
            taskOne = state.text
            taskOneDone = state.done
            todoistIDOne = state.link.taskID
            todoistSyncedContentOne = state.link.syncedContent
            todoistSyncedDoneOne = state.link.syncedDone
        case 1:
            taskTwo = state.text
            taskTwoDone = state.done
            todoistIDTwo = state.link.taskID
            todoistSyncedContentTwo = state.link.syncedContent
            todoistSyncedDoneTwo = state.link.syncedDone
        default:
            taskThree = state.text
            taskThreeDone = state.done
            todoistIDThree = state.link.taskID
            todoistSyncedContentThree = state.link.syncedContent
            todoistSyncedDoneThree = state.link.syncedDone
        }
    }

    /// Swaps two slots, so a task's Todoist link moves with it when tasks are reordered.
    func swapSlots(_ first: Int, _ second: Int) {
        guard first != second else { return }
        let firstState = slotState(first)
        let secondState = slotState(second)
        apply(secondState, to: first)
        apply(firstState, to: second)
    }

    /// True if any slot is linked to a Todoist task.
    var hasTodoistLinks: Bool {
        (0..<Self.slotCount).contains { todoistLink(in: $0).isLinked }
    }
}
