//
//  DemoMode.swift
//  Daily Three
//
//  A debug-only mode for taking App Store screenshots with clean sample data. It starts the app with an
//  in-memory store (no iCloud, no real data) and never exists in release builds.
//
//  Launch with the argument `-DemoMode` (or the environment variable DEMO_MODE=1). Optional variables:
//    DEMO_THEME       sunrise | ocean | forest | graphite   (default graphite)
//    DEMO_APPEARANCE  system | light | dark                  (default system)
//    DEMO_DONE        how many of today's tasks are checked off, 0 to 3 (default 1)
//    DEMO_NOTES       "full" fills in the Completion note too
//

#if DEBUG
import Foundation
import SwiftData

enum DemoMode {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-DemoMode")
            || ProcessInfo.processInfo.environment["DEMO_MODE"] == "1"
    }

    private static var environment: [String: String] { ProcessInfo.processInfo.environment }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([DayEntry.self, AppSettings.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            seed(container.mainContext)
            return container
        } catch {
            fatalError("Could not create the demo ModelContainer: \(error)")
        }
    }

    // MARK: - Seeding

    private static func seed(_ context: ModelContext) {
        let settings = AppSettings()
        settings.theme = ThemeOption(rawValue: environment["DEMO_THEME"] ?? "") ?? .graphite
        settings.appearanceMode = AppearanceMode(rawValue: environment["DEMO_APPEARANCE"] ?? "") ?? .system
        settings.hasCompletedOnboarding = true
        context.insert(settings)

        let doneCount = min(3, max(0, Int(environment["DEMO_DONE"] ?? "") ?? 1))
        let fullNotes = environment["DEMO_NOTES"] == "full"

        let today = DayEntry(date: Date())
        today.taskOne = "Finish the launch plan"
        today.taskTwo = "Send the Tuesday newsletter"
        today.taskThree = "Take a long walk"
        today.taskOneDone = doneCount >= 1
        today.taskTwoDone = doneCount >= 2
        today.taskThreeDone = doneCount >= 3
        today.progressNote = "The launch plan is drafted. The newsletter outline is next, then a walk to clear my head."
        today.completionNote = fullNotes ? "Shipped the plan, sent the newsletter, and caught the sunset on my walk. A good day." : ""
        context.insert(today)

        // The past week, for the Archive.
        let past: [(tasks: [String], done: [Bool], progress: String, completion: String)] = [
            (["Draft the launch plan", "Review the pull requests", "Call Mom"], [true, true, true],
             "The plan outline came together fast.", "Everything done, and the call was a nice break."),
            (["Outline the newsletter", "Fix the sync bug", "Clear my inbox"], [true, true, false],
             "Bug fixed after lunch.", "Inbox can wait until tomorrow."),
            (["Record the podcast", "Edit the show notes", "Book flights"], [true, true, true],
             "", "Recorded in one take. Flights are booked."),
            (["Write 500 words", "Go to the gym", "Plan the week"], [true, false, true],
             "Words first, then everything else.", "Skipped the gym, but the week is planned."),
            (["Ship the beta", "Reply to testers", "Walk the dog"], [true, true, true],
             "Beta is out.", "Testers are happy. The dog is happier."),
            (["Tidy the desk", "Read for 30 minutes", "Prep for tomorrow"], [true, true, true],
             "", "A calm, quiet day."),
            (["Pay the invoices", "Backup the photos", "Stretch"], [true, true, false],
             "", "Stretching tomorrow, I promise.")
        ]
        for (offset, day) in past.enumerated() {
            guard let date = Calendar.current.date(byAdding: .day, value: -(offset + 1), to: Date()) else { continue }
            let entry = DayEntry(date: date)
            entry.taskOne = day.tasks[0]
            entry.taskTwo = day.tasks[1]
            entry.taskThree = day.tasks[2]
            entry.taskOneDone = day.done[0]
            entry.taskTwoDone = day.done[1]
            entry.taskThreeDone = day.done[2]
            entry.progressNote = day.progress
            entry.completionNote = day.completion
            context.insert(entry)
        }

        try? context.save()
    }
}
#endif
