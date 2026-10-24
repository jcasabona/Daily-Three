//
//  NotificationScheduler.swift
//  Daily Three
//

import Foundation
import UserNotifications

final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            self.center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        }
    }

    func scheduleDailyNotifications(with settings: AppSettings, entry: DayEntry?) {
        let shouldSkipMorning = entry?.hasAllTasksSet ?? false
        var requests = [
            NotificationRequest(identifier: "daily-three-midday",
                                time: settings.middayTime,
                                title: "Daily Three",
                                body: "How are you progressing on your tasks?"),
            NotificationRequest(identifier: "daily-three-evening",
                                time: settings.eveningTime,
                                title: "Daily Three",
                                body: "Did you complete your tasks?")
        ]

        if !shouldSkipMorning {
            requests.insert(NotificationRequest(identifier: "daily-three-morning",
                                                time: settings.morningTime,
                                                title: "Daily Three",
                                                body: "What are the 3 tasks you want to accomplish today?"),
                            at: 0)
        }

        // Clear the base identifiers (including the legacy un-suffixed ones) and every per-weekday variant.
        let baseIdentifiers = ["daily-three-morning", "daily-three-midday", "daily-three-evening"]
        let staleIdentifiers = baseIdentifiers + baseIdentifiers.flatMap { base in (1...7).map { "\(base)-\($0)" } }
        center.removePendingNotificationRequests(withIdentifiers: staleIdentifiers)

        let excluded = settings.excludedWeekdays
        for request in requests {
            let content = UNMutableNotificationContent()
            content.title = request.title
            content.body = request.body
            content.sound = .default

            let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: request.time)

            // One repeating trigger per active weekday so excluded days stay silent.
            for weekday in 1...7 where !excluded.contains(weekday) {
                var components = timeComponents
                components.weekday = weekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let notification = UNNotificationRequest(identifier: "\(request.identifier)-\(weekday)", content: content, trigger: trigger)
                center.add(notification)
            }
        }
    }
}

private struct NotificationRequest {
    let identifier: String
    let time: Date
    let title: String
    let body: String
}
