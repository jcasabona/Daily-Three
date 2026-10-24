//
//  TodoistModels.swift
//  Daily Three
//
//  Types for the Todoist API v1 (https://api.todoist.com/api/v1). Field names follow Todoist's OpenAPI spec.
//

import Foundation

struct TodoistTask: Decodable, Equatable, Identifiable, Sendable {
    struct Due: Decodable, Equatable, Sendable {
        let date: String?
        let string: String?
        let isRecurring: Bool

        private enum CodingKeys: String, CodingKey {
            case date, string
            case isRecurring = "is_recurring"
        }

        init(date: String?, string: String?, isRecurring: Bool) {
            self.date = date
            self.string = string
            self.isRecurring = isRecurring
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try container.decodeIfPresent(String.self, forKey: .date)
            string = try container.decodeIfPresent(String.self, forKey: .string)
            isRecurring = try container.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? false
        }
    }

    let id: String
    let content: String
    let checked: Bool
    let isDeleted: Bool
    let projectID: String?
    let due: Due?

    var isRecurring: Bool { due?.isRecurring ?? false }

    private enum CodingKeys: String, CodingKey {
        case id, content, checked, due
        case isDeleted = "is_deleted"
        case projectID = "project_id"
    }

    init(id: String, content: String, checked: Bool = false, isDeleted: Bool = false, projectID: String? = nil, due: Due? = nil) {
        self.id = id
        self.content = content
        self.checked = checked
        self.isDeleted = isDeleted
        self.projectID = projectID
        self.due = due
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        checked = try container.decodeIfPresent(Bool.self, forKey: .checked) ?? false
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        projectID = try container.decodeIfPresent(String.self, forKey: .projectID)
        due = try container.decodeIfPresent(Due.self, forKey: .due)
    }
}

struct TodoistProject: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let isInbox: Bool

    private enum CodingKeys: String, CodingKey {
        case id, name
        case isInbox = "inbox_project"
    }

    init(id: String, name: String, isInbox: Bool = false) {
        self.id = id
        self.name = name
        self.isInbox = isInbox
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isInbox = try container.decodeIfPresent(Bool.self, forKey: .isInbox) ?? false
    }
}

/// Todoist's cursor-paginated list envelope: `{ "results": [...], "next_cursor": "..." | null }`.
struct TodoistPage<Item: Decodable & Sendable>: Decodable, Sendable {
    let results: [Item]
    let nextCursor: String?

    private enum CodingKeys: String, CodingKey {
        case results
        case nextCursor = "next_cursor"
    }
}

/// The completed-tasks endpoint uses `items` rather than `results`.
struct TodoistCompletedPage: Decodable, Sendable {
    let items: [TodoistTask]
    let nextCursor: String?

    private enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([TodoistTask].self, forKey: .items) ?? []
        nextCursor = try container.decodeIfPresent(String.self, forKey: .nextCursor)
    }
}

enum TodoistError: LocalizedError, Equatable {
    case notConnected
    case unauthorized
    case notFound
    case rateLimited
    case server(Int)
    case network(String)
    case unreadableResponse

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Todoist isn't connected. Add your API token in Settings."
        case .unauthorized:
            return "Todoist rejected the API token. Check it in Settings, or copy a fresh one from Todoist."
        case .notFound:
            return "That Todoist item no longer exists."
        case .rateLimited:
            return "Todoist is asking us to slow down. Try again in a minute."
        case .server(let code):
            return "Todoist returned an error (HTTP \(code))."
        case .network(let message):
            return "Couldn't reach Todoist: \(message)"
        case .unreadableResponse:
            return "Todoist sent a response the app couldn't read."
        }
    }
}
