//
//  TodoistClient.swift
//  Daily Three
//
//  A small client for the Todoist API v1. The network layer is a protocol so the sync logic can be
//  exercised against a fake Todoist.
//

import Foundation

protocol TodoistTransport {
    /// Sends a request and returns the body and HTTP status code.
    func send(_ request: URLRequest) async throws -> (data: Data, status: Int)
}

struct URLSessionTodoistTransport: TodoistTransport {
    var session: URLSession = .shared

    func send(_ request: URLRequest) async throws -> (data: Data, status: Int) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw TodoistError.unreadableResponse }
            return (data, http.statusCode)
        } catch let error as TodoistError {
            throw error
        } catch {
            throw TodoistError.network(error.localizedDescription)
        }
    }
}

struct TodoistClient {
    static let baseURL = URL(string: "https://api.todoist.com/api/v1")!
    /// Upper bound on pages fetched for one listing, so a huge account can't cause a request storm.
    static let maxPages = 5
    static let pageSize = 200

    let token: String
    var transport: TodoistTransport = URLSessionTodoistTransport()

    // MARK: - Tasks

    /// Active tasks, optionally narrowed by a Todoist filter query such as `today | overdue`.
    func activeTasks(filter: String? = nil) async throws -> [TodoistTask] {
        if let filter, !filter.trimmed.isEmpty {
            return try await allPages("tasks/filter", query: [URLQueryItem(name: "query", value: filter)])
        }
        return try await allPages("tasks", query: [])
    }

    /// Active tasks with the given IDs. Completed or deleted tasks are simply absent from the result.
    func activeTasks(ids: [String]) async throws -> [TodoistTask] {
        guard !ids.isEmpty else { return [] }
        var found: [TodoistTask] = []
        for chunk in stride(from: 0, to: ids.count, by: 50).map({ Array(ids[$0..<min($0 + 50, ids.count)]) }) {
            found += try await allPages("tasks", query: [URLQueryItem(name: "ids", value: chunk.joined(separator: ","))])
        }
        return found
    }

    /// Tasks completed in the given window (Todoist allows at most 3 months). The completed-tasks endpoint
    /// wraps its list in `items` instead of `results`.
    func completedTasks(since: Date, until: Date) async throws -> [TodoistTask] {
        let formatter = ISO8601DateFormatter()
        var tasks: [TodoistTask] = []
        var cursor: String?
        for _ in 0..<Self.maxPages {
            var query = [URLQueryItem(name: "since", value: formatter.string(from: since)),
                         URLQueryItem(name: "until", value: formatter.string(from: until))]
            if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
            let data = try await send("GET", "tasks/completed/by_completion_date", query: query)
            let page = try decode(TodoistCompletedPage.self, from: data)
            tasks += page.items
            guard let next = page.nextCursor, !next.isEmpty else { break }
            cursor = next
        }
        return tasks
    }

    func createTask(content: String, dueDate: String?, projectID: String?) async throws -> TodoistTask {
        var body = ["content": content]
        if let dueDate, !dueDate.isEmpty { body["due_date"] = dueDate }
        if let projectID, !projectID.isEmpty { body["project_id"] = projectID }
        let data = try await send("POST", "tasks", body: body)
        return try decode(TodoistTask.self, from: data)
    }

    func updateTask(id: String, content: String) async throws {
        _ = try await send("POST", "tasks/\(id)", body: ["content": content])
    }

    func closeTask(id: String) async throws {
        _ = try await send("POST", "tasks/\(id)/close")
    }

    func reopenTask(id: String) async throws {
        _ = try await send("POST", "tasks/\(id)/reopen")
    }

    // MARK: - Projects

    func projects() async throws -> [TodoistProject] {
        try await allPages("projects", query: [])
    }

    // MARK: - Plumbing

    private func allPages<Item: Decodable>(_ path: String, query: [URLQueryItem]) async throws -> [Item] {
        var items: [Item] = []
        var cursor: String?
        for _ in 0..<Self.maxPages {
            var pageQuery = query + [URLQueryItem(name: "limit", value: String(Self.pageSize))]
            if let cursor { pageQuery.append(URLQueryItem(name: "cursor", value: cursor)) }
            let data = try await send("GET", path, query: pageQuery)
            let page = try decode(TodoistPage<Item>.self, from: data)
            items += page.results
            guard let next = page.nextCursor, !next.isEmpty else { break }
            cursor = next
        }
        return items
    }

    private func send(_ method: String, _ path: String, query: [URLQueryItem] = [], body: [String: String]? = nil) async throws -> Data {
        guard var components = URLComponents(url: Self.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw TodoistError.unreadableResponse
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw TodoistError.unreadableResponse }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, status) = try await transport.send(request)
        switch status {
        case 200..<300: return data
        case 401, 403: throw TodoistError.unauthorized
        case 404: throw TodoistError.notFound
        case 429: throw TodoistError.rateLimited
        default: throw TodoistError.server(status)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw TodoistError.unreadableResponse
        }
    }
}
