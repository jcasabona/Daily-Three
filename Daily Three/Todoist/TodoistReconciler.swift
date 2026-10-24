//
//  TodoistReconciler.swift
//  Daily Three
//
//  The merge rules for one task slot, kept free of networking and storage so they can be tested directly.
//

import Foundation

/// The link between a task slot and a Todoist task.
struct TodoistLink: Equatable {
    var taskID: String = ""
    /// The title and completion both sides agreed on at the last sync.
    var syncedContent: String = ""
    var syncedDone: Bool = false

    var isLinked: Bool { !taskID.isEmpty }
}

struct TodoistSlotState: Equatable {
    var text: String
    var done: Bool
    var link: TodoistLink
}

struct TodoistSlotPlan: Equatable {
    /// What the slot should look like once the plan is applied.
    var state: TodoistSlotState
    /// Rename the Todoist task to this.
    var pushContent: String?
    /// Complete (`true`) or reopen (`false`) the Todoist task.
    var pushDone: Bool?

    var needsRemoteChange: Bool { pushContent != nil || pushDone != nil }
}

enum TodoistReconciler {
    /// Decides how a linked slot and its Todoist task should be brought back in step.
    ///
    /// Each field is compared with the value both sides last agreed on, so we can tell which side changed:
    /// - changed only in the app: push it to Todoist
    /// - changed only in Todoist: pull it into the app
    /// - changed on both sides to different values: the app wins, since that's what the person is editing
    ///
    /// - Parameter remote: the Todoist task, or `nil` if it was deleted or can no longer be found.
    static func reconcile(_ local: TodoistSlotState, remote: TodoistTask?) -> TodoistSlotPlan {
        var plan = TodoistSlotPlan(state: local)
        guard local.link.isLinked else { return plan }

        // The Todoist task is gone: keep the text and drop the link. The text stays recorded as "synced", so the
        // sync doesn't see an unlinked task and create it all over again.
        guard let remote, !remote.isDeleted else {
            plan.state.link = TodoistLink(taskID: "", syncedContent: local.text, syncedDone: local.done)
            return plan
        }

        // The title was cleared in the app: unlink without touching Todoist.
        if local.text.trimmed.isEmpty {
            plan.state.link = TodoistLink()
            return plan
        }

        // Title
        let syncedContent = local.link.syncedContent
        let localEdited = local.text != syncedContent
        let remoteEdited = remote.content != syncedContent
        var content = local.text
        if localEdited {
            if local.text != remote.content { plan.pushContent = local.text }
        } else if remoteEdited {
            content = remote.content
        }
        plan.state.text = content
        plan.state.link.syncedContent = content

        // Completion
        let syncedDone = local.link.syncedDone
        var done = local.done
        if remote.isRecurring {
            // Closing a recurring task moves it to its next date, so it never reads as completed in Todoist.
            // Completion is therefore push-only, and unchecking in the app doesn't reopen anything.
            if local.done && !syncedDone { plan.pushDone = true }
        } else {
            let localChanged = local.done != syncedDone
            let remoteChanged = remote.checked != syncedDone
            if localChanged {
                if local.done != remote.checked { plan.pushDone = local.done }
            } else if remoteChanged {
                done = remote.checked
            }
        }
        plan.state.done = done
        plan.state.link.syncedDone = done
        return plan
    }
}
