//
//  CSVImporter.swift
//  Daily Three
//
//  Imports the CSV produced by Settings → Export CSV.
//

import Foundation
import SwiftData

enum CSVImporter {
    struct Summary {
        var added = 0
        var merged = 0
        var skipped = 0

        var description: String {
            var parts: [String] = []
            parts.append("\(added) new \(added == 1 ? "day" : "days") added")
            if merged > 0 { parts.append("\(merged) existing \(merged == 1 ? "day" : "days") merged") }
            if skipped > 0 { parts.append("\(skipped) \(skipped == 1 ? "row" : "rows") skipped") }
            return parts.joined(separator: ", ") + "."
        }
    }

    enum ImportError: LocalizedError {
        case unrecognizedFormat

        var errorDescription: String? {
            switch self {
            case .unrecognizedFormat:
                return "This doesn't look like a Daily Three export. The file needs a header row that starts with a \"date\" column."
            }
        }
    }

    /// Imports `text` into `context`. Days that already exist are merged with the same rules
    /// used for CloudKit deduplication, so importing never overwrites or duplicates entries.
    @MainActor
    static func importCSV(_ text: String, into context: ModelContext) throws -> Summary {
        let rows = parseRows(text)
        guard let header = rows.first else { throw ImportError.unrecognizedFormat }

        let columns = Dictionary(
            header.enumerated().map { ($1.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        guard let dateColumn = columns["date"] else { throw ImportError.unrecognizedFormat }

        var existing = Dictionary(
            try context.fetch(FetchDescriptor<DayEntry>()).map { ($0.dateKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var summary = Summary()

        for row in rows.dropFirst() {
            // Ignore blank lines.
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }

            func value(_ name: String) -> String {
                guard let index = columns[name], index < row.count else { return "" }
                return row[index]
            }

            guard dateColumn < row.count, let date = parseDate(row[dateColumn]) else {
                summary.skipped += 1
                continue
            }

            let imported = DayEntry(date: date)
            imported.taskOne = value("task_one")
            imported.taskTwo = value("task_two")
            imported.taskThree = value("task_three")
            imported.taskOneDone = parseBool(value("task_one_done"))
            imported.taskTwoDone = parseBool(value("task_two_done"))
            imported.taskThreeDone = parseBool(value("task_three_done"))
            imported.progressNote = value("progress_note")
            imported.completionNote = value("completion_note")

            if let current = existing[imported.dateKey] {
                DayEntryDeduplicator.merge(from: imported, into: current)
                summary.merged += 1
            } else {
                context.insert(imported)
                existing[imported.dateKey] = imported
                summary.added += 1
            }
        }

        if context.hasChanges {
            try context.save()
        }
        return summary
    }

    // MARK: - Parsing

    /// Parses `yyyy-MM-dd` as a local calendar day, so the entry lands on the same date it was exported from.
    private static func parseDate(_ string: String) -> Date? {
        let parts = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "-")
            .compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        return Calendar.current.date(from: components)
    }

    private static func parseBool(_ string: String) -> Bool {
        string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
    }

    /// Minimal RFC 4180 parser: quoted fields, escaped quotes (`""`), and line breaks inside quotes.
    static func parseRows(_ input: String) -> [[String]] {
        var text = input
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }

        let characters = Array(text)
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if inQuotes {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"" {
                inQuotes = true
            } else if character == "," {
                row.append(field)
                field = ""
            } else if character == "\n" || character == "\r" || character == "\r\n" {
                // Swift treats "\r\n" as a single Character.
                row.append(field)
                field = ""
                rows.append(row)
                row = []
            } else {
                field.append(character)
            }

            index += 1
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}
