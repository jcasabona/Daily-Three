//
//  TodoistSyncService.swift
//  Daily Three
//
//  Keeps the three task slots and their linked Todoist tasks in step.
//

import Foundation
import SwiftData
import Observation
import WidgetKit

@MainActor
@Observable
final class TodoistSyncService {
    enum Status: Equatable {
        case idle
        case syncing
        case failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var lastSync: Date?
    private(set) var isConnected: Bool

    /// Replaceable so the sync can be exercised without the network.
    var transport: TodoistTransport = URLSessionTodoistTransport()

    /// How far back to look when a linked task has vanished from the active list, to tell completed from deleted.
    private let completedLookback: TimeInterval = 30 * 24 * 60 * 60
    private var needsAnotherPass = false

    init() {
        isConnected = TodoistTokenStore.load() != nil
    }

    private var client: TodoistClient? {
        TodoistTokenStore.load().map { TodoistClient(token: $0, transport: transport) }
    }

    // MARK: - Connection

    /// Checks the token against Todoist, then stores it in the Keychain.
    func connect(token: String) async throws {
        let trimmed = token.trimmed
        guard !trimmed.isEmpty else { throw TodoistError.unauthorized }
        _ = try await TodoistClient(token: trimmed, transport: transport).projects()
        try TodoistTokenStore.save(trimmed)
        isConnected = true
        status = .idle
    }

    /// Forgets the token. Existing links stay in place, and syncing resumes if the token is added again.
    func disconnect() {
        TodoistTokenStore.delete()
        isConnected = false
        status = .idle
        lastSync = nil
    }

    // MARK: - Lookups for the UI

    func projects() async throws -> [TodoistProject] {
        guard let client else { throw TodoistError.notConnected }
        return try await client.projects()
    }

    /// Active tasks to choose from. `filter` is a Todoist filter query such as `today | overdue`; `nil` means all.
    func pickableTasks(filter: String?) async throws -> [TodoistTask] {
        guard let client else { throw TodoistError.notConnected }
        return try await client.activeTasks(filter: filter)
    }

    // MARK: - Linking

    /// Points a slot at an existing Todoist task and takes on its title.
    func link(_ task: TodoistTask, toSlot slot: Int, in entry: DayEntry) {
        var state = entry.slotState(slot)
        state.text = task.content
        state.done = false
        state.link = TodoistLink(taskID: task.id, syncedContent: task.content, syncedDone: false)
        entry.apply(state, to: slot)
    }

    /// Removes the link but leaves the text and the Todoist task as they are. The text stays recorded as
    /// "synced", so it isn't recreated in Todoist; editing it later does create a new task.
    func unlink(slot: Int, in entry: DayEntry) {
        var state = entry.slotState(slot)
        state.link = TodoistLink(taskID: "", syncedContent: state.text, syncedDone: state.done)
        entry.apply(state, to: slot)
    }

    // MARK: - Sync

    /// Reconciles today's and upcoming days' tasks with Todoist. Safe to call often: overlapping calls
    /// are coalesced into one extra pass.
    func sync(context: ModelContext, settings: AppSettings?) async {
        guard let client else { return }
        if status == .syncing {
            needsAnotherPass = true
            return
        }
        status = .syncing
        repeat {
            needsAnotherPass = false
            do {
                try await performSync(client: client, context: context, settings: settings)
                lastSync = Date()
                status = .idle
            } catch {
                status = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
                return
            }
        } while needsAnotherPass
    }

    private func performSync(client: TodoistClient, context: ModelContext, settings: AppSettings?) async throws {
        let todayKey = DayEntry.makeDateKey(for: Date())
        let entries = try context.fetch(FetchDescriptor<DayEntry>()).filter { $0.dateKey >= todayKey }
        var changed = false

        // 1. Look up every linked task: active ones in one request, then find out what became of the rest.
        let linkedIDs = Set(entries.flatMap { entry in
            (0..<DayEntry.slotCount).map { entry.todoistLink(in: $0).taskID }
        }).filter { !$0.isEmpty }

        var remoteByID: [String: TodoistTask] = [:]
        if !linkedIDs.isEmpty {
            for task in try await client.activeTasks(ids: Array(linkedIDs)) { remoteByID[task.id] = task }
            let missing = linkedIDs.subtracting(remoteByID.keys)
            if !missing.isEmpty {
                let now = Date()
                let completed = try await client.completedTasks(since: now.addingTimeInterval(-completedLookback),
                                                                until: now.addingTimeInterval(24 * 60 * 60))
                for task in completed where missing.contains(task.id) {
                    remoteByID[task.id] = TodoistTask(id: task.id, content: task.content, checked: true,
                                                      projectID: task.projectID, due: task.due)
                }
            }
        }

        // 2. Merge each linked slot, pushing app-side changes to Todoist first.
        var firstSlotError: Error?
        for entry in entries {
            for slot in 0..<DayEntry.slotCount {
                let local = entry.slotState(slot)
                guard local.link.isLinked else { continue }
                let plan = TodoistReconciler.reconcile(local, remote: remoteByID[local.link.taskID])
                do {
                    try await push(plan, taskID: local.link.taskID, client: client)
                } catch let error as TodoistError where error == .notFound {
                    var gone = local
                    gone.link = TodoistLink(taskID: "", syncedContent: local.text, syncedDone: local.done)
                    entry.apply(gone, to: slot)
                    changed = true
                    continue
                } catch let error as TodoistError where error == .unauthorized || error == .rateLimited {
                    throw error
                } catch {
                    firstSlotError = firstSlotError ?? error
                    continue
                }
                if plan.state != local {
                    entry.apply(plan.state, to: slot)
                    changed = true
                }
            }
        }

        // 3. Create Todoist tasks for typed-in tasks that aren't linked yet.
        if settings?.todoistCreatesTasks ?? true {
            let projectID = settings?.todoistProjectID
            for entry in entries {
                for slot in 0..<DayEntry.slotCount {
                    let local = entry.slotState(slot)
                    // Only text that hasn't been synced or deliberately unlinked becomes a new Todoist task.
                    guard !local.link.isLinked, !local.done, !local.text.trimmed.isEmpty,
                          local.link.syncedContent != local.text else { continue }
                    do {
                        let created = try await client.createTask(content: local.text, dueDate: entry.dateKey, projectID: projectID)
                        var linked = local
                        linked.link = TodoistLink(taskID: created.id, syncedContent: local.text, syncedDone: false)
                        entry.apply(linked, to: slot)
                        changed = true
                        // Save right away so the link reaches other devices before they try to create a duplicate.
                        try context.save()
                    } catch let error as TodoistError where error == .unauthorized || error == .rateLimited {
                        throw error
                    } catch {
                        firstSlotError = firstSlotError ?? error
                    }
                }
            }
        }

        if changed || context.hasChanges {
            try context.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
        if let firstSlotError { throw firstSlotError }
    }

    private func push(_ plan: TodoistSlotPlan, taskID: String, client: TodoistClient) async throws {
        if let content = plan.pushContent {
            try await client.updateTask(id: taskID, content: content)
        }
        if let done = plan.pushDone {
            if done {
                try await client.closeTask(id: taskID)
            } else {
                try await client.reopenTask(id: taskID)
            }
        }
    }
}
