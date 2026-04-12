//
//  DeepLinkRouter.swift
//  Daily Three
//

import Foundation
import Observation

enum DeepLinkAction: Equatable {
    case openTab(AppTab)
    case setTasks(task1: String?, task2: String?, task3: String?)
    case addProgressNote(text: String, mode: NoteMode)
    case addCompletionNote(text: String, mode: NoteMode)
    case completeTask(slot: TaskSlot, value: CompletionValue)
}

enum NoteMode: String, Equatable {
    case append
    case set
}

enum TaskSlot: Equatable {
    case one
    case two
    case three
    case all
}

enum CompletionValue: String, Equatable {
    case `true`
    case `false`
    case toggle
}

@Observable
final class DeepLinkRouter {
    var pendingAction: DeepLinkAction?
    private(set) var lastHandledAt: Date?

    var hasPendingAction: Bool {
        pendingAction != nil
    }

    var recentlyHandled: Bool {
        guard let t = lastHandledAt else { return false }
        return Date().timeIntervalSince(t) < 2.0
    }

    func handle(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "dailythree" else { return }

        let host = components.host ?? ""
        let params = queryDict(from: components.queryItems)

        switch host {
        case "open":
            if let tabName = params["tab"], let tab = AppTab(urlValue: tabName) {
                pendingAction = .openTab(tab)
            }

        case "tasks":
            pendingAction = .setTasks(
                task1: params["t1"],
                task2: params["t2"],
                task3: params["t3"]
            )

        case "progress":
            if let text = params["text"], !text.isEmpty {
                let mode = NoteMode(rawValue: params["mode"] ?? "append") ?? .append
                pendingAction = .addProgressNote(text: text, mode: mode)
            }

        case "completion":
            if let text = params["text"], !text.isEmpty {
                let mode = NoteMode(rawValue: params["mode"] ?? "append") ?? .append
                pendingAction = .addCompletionNote(text: text, mode: mode)
            }

        case "complete":
            if let taskStr = params["task"],
               let slot = parseTaskSlot(taskStr),
               let valStr = params["value"],
               let value = CompletionValue(rawValue: valStr) {
                pendingAction = .completeTask(slot: slot, value: value)
            }

        default:
            break
        }
    }

    func consumeAction() -> DeepLinkAction? {
        let action = pendingAction
        pendingAction = nil
        if action != nil { lastHandledAt = Date() }
        return action
    }

    private func queryDict(from items: [URLQueryItem]?) -> [String: String] {
        var dict: [String: String] = [:]
        for item in items ?? [] {
            if let value = item.value {
                dict[item.name] = value.replacingOccurrences(of: "+", with: " ")
            }
        }
        return dict
    }

    private func parseTaskSlot(_ string: String) -> TaskSlot? {
        switch string {
        case "1": return .one
        case "2": return .two
        case "3": return .three
        case "all": return .all
        default: return nil
        }
    }
}
