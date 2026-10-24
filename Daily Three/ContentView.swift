//
//  ContentView.swift
//  Daily Three
//
//  Created by Joe Casabona on 3/5/26.
//

import SwiftUI
import SwiftData
import CoreData
import Combine
import WidgetKit

enum AppTab: Hashable {
    case today
    case archive
    case settings

    init?(urlValue: String) {
        switch urlValue.lowercased() {
        case "today": self = .today
        case "archive": self = .archive
        case "settings": self = .settings
        default: return nil
        }
    }
}

enum DayEditingMode {
    case today
    case future
    case readOnly
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(DeepLinkRouter.self) private var router
    @Query(sort: \DayEntry.date, order: .reverse) private var entries: [DayEntry]
    @Query private var settingsList: [AppSettings]

    @State private var showingOnboarding = false
    @State private var selectedTab: AppTab = .today
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    private var todayKey: String {
        DayEntry.makeDateKey(for: Date())
    }

    private var todayEntry: DayEntry? {
        entries.first { $0.dateKey == todayKey }
    }

    private var settings: AppSettings? {
        settingsList.first
    }

    private var editingMode: DayEditingMode {
        let todayStart = Calendar.current.startOfDay(for: Date())
        if Calendar.current.isDate(selectedDate, inSameDayAs: todayStart) { return .today }
        if selectedDate > todayStart { return .future }
        return .readOnly
    }

    private var selectableDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let excluded = settings?.excludedWeekdays ?? []
        return (0...7)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
            .filter { date in
                // Today always stays selectable so the screen never opens on a hidden day.
                calendar.isDate(date, inSameDayAs: today) || !excluded.contains(calendar.component(.weekday, from: date))
            }
    }

    private var archiveEntries: [DayEntry] {
        let key = todayKey
        return entries.filter { $0.dateKey <= key }
    }

    #if os(macOS)
    private var mainContainer: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case .today:
                    TodayView(
                        entry: bindingForEntry(on: selectedDate),
                        theme: currentTheme(),
                        editingMode: editingMode,
                        selectableDates: selectableDates,
                        selectedDate: $selectedDate,
                        onSnapshotChange: writeSnapshotForToday,
                        onTasksSetChange: scheduleNotificationsIfPossible
                    )
                case .archive:
                    ArchiveView(entries: archiveEntries, theme: currentTheme())
                case .settings:
                    if let settings {
                        SettingsView(settings: settings, theme: currentTheme())
                    } else {
                        ProgressView()
                    }
                }
            }
            .toolbar(removing: .title)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Text("Daily Three")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                }
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $selectedTab) {
                        Text("Today").tag(AppTab.today)
                        Text("Archive").tag(AppTab.archive)
                        Text("Settings").tag(AppTab.settings)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 250)
                }
            }
        }
        .tint(currentTheme().accent)
    }
    #else
    private var mainContainer: some View {
        TabView(selection: $selectedTab) {
            TodayView(
                entry: bindingForEntry(on: selectedDate),
                theme: currentTheme(),
                editingMode: editingMode,
                selectableDates: selectableDates,
                selectedDate: $selectedDate,
                onSnapshotChange: writeSnapshotForToday,
                onTasksSetChange: scheduleNotificationsIfPossible
            )
                .tabItem {
                    Label("Today", systemImage: "checklist")
                }
                .tag(AppTab.today)

            ArchiveView(entries: archiveEntries, theme: currentTheme())
                .tabItem {
                    Label("Archive", systemImage: "calendar")
                }
                .tag(AppTab.archive)

            if let settings {
                SettingsView(settings: settings, theme: currentTheme())
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(AppTab.settings)
            } else {
                ProgressView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(AppTab.settings)
            }
        }
        .tint(currentTheme().accent)
    }
    #endif

    var body: some View {
        mainContainer
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            ensureSettings()
            DayEntryDeduplicator.deduplicateIfNeeded(context: modelContext)
            AppSettingsDeduplicator.deduplicateIfNeeded(context: modelContext)
            requestNotificationsIfNeeded()
            writeSnapshotForToday()
            if !router.hasPendingAction {
                selectedTab = .today
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && !router.recentlyHandled {
                selectedTab = .today
                let today = Calendar.current.startOfDay(for: Date())
                if selectedDate < today {
                    selectedDate = today
                }
            }
        }
        .onOpenURL { url in
            router.handle(url: url)
            if let action = router.consumeAction() {
                handleDeepLink(action)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: DispatchQueue.main)) { _ in
            DayEntryDeduplicator.deduplicateIfNeeded(context: modelContext)
            AppSettingsDeduplicator.deduplicateIfNeeded(context: modelContext)
            writeSnapshotForToday()
        }
        .onChange(of: settings?.morningTime) { _, _ in
            scheduleNotificationsIfPossible()
        }
        .onChange(of: settings?.middayTime) { _, _ in
            scheduleNotificationsIfPossible()
        }
        .onChange(of: settings?.eveningTime) { _, _ in
            scheduleNotificationsIfPossible()
        }
        .onChange(of: settingsList.count) { _, _ in
            scheduleNotificationsIfPossible()
        }
        .onChange(of: settings?.excludedWeekdaysRaw) { _, _ in
            scheduleNotificationsIfPossible()
        }
        .onChange(of: settings?.themeRaw) { _, _ in
            showingOnboarding = false
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showingOnboarding) {
            if let settings {
                OnboardingView(settings: settings, entry: bindingForTodayEntry(), theme: currentTheme(), onSnapshotChange: writeSnapshotForToday)
            }
        }
        #else
        .sheet(isPresented: $showingOnboarding) {
            if let settings {
                OnboardingView(settings: settings, entry: bindingForTodayEntry(), theme: currentTheme(), onSnapshotChange: writeSnapshotForToday)
            } else {
                ProgressView()
            }
        }
        #endif
        .task {
            let completedOnboarding = settings?.hasCompletedOnboarding ?? false
            if completedOnboarding {
                showingOnboarding = false
                return
            }

            if let entry = todayEntry {
                showingOnboarding = entry.taskOne.isEmpty && entry.taskTwo.isEmpty && entry.taskThree.isEmpty
            } else {
                showingOnboarding = true
            }
        }
    }

    private func bindingForEntry(on date: Date) -> Binding<DayEntry> {
        let key = DayEntry.makeDateKey(for: date)
        if let existing = entries.first(where: { $0.dateKey == key }) {
            return Binding(get: { existing }, set: { _ in })
        }
        let newEntry = DayEntry(date: date)
        modelContext.insert(newEntry)
        return Binding(get: { newEntry }, set: { _ in })
    }

    private func bindingForTodayEntry() -> Binding<DayEntry> {
        bindingForEntry(on: Date())
    }

    private func ensureSettings() {
        guard settings == nil else { return }
        let newSettings = AppSettings()
        modelContext.insert(newSettings)
    }

    private func requestNotificationsIfNeeded() {
        NotificationScheduler.shared.requestAuthorizationIfNeeded()
    }

    private func scheduleNotificationsIfPossible() {
        guard let settings else { return }
        NotificationScheduler.shared.scheduleDailyNotifications(with: settings, entry: todayEntry)
    }

    private func currentTheme() -> ThemePalette {
        let option = settings?.theme ?? .sunrise
        return ThemePalette(option: option)
    }

    private var preferredColorScheme: ColorScheme? {
        settings?.appearanceMode.colorScheme
    }

    private func writeSnapshotForToday() {
        do {
            try modelContext.save()
        } catch {
            // Save failures shouldn't block snapshot updates.
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func handleDeepLink(_ action: DeepLinkAction) {
        let entry: DayEntry
        if let existing = todayEntry {
            entry = existing
        } else {
            let newEntry = DayEntry(date: Date())
            modelContext.insert(newEntry)
            entry = newEntry
        }

        switch action {
        case .openTab(let tab):
            selectedTab = tab

        case .setTasks(let t1, let t2, let t3):
            if let t1 { entry.taskOne = t1 }
            if let t2 { entry.taskTwo = t2 }
            if let t3 { entry.taskThree = t3 }
            selectedTab = .today
            writeSnapshotForToday()

        case .addProgressNote(let text, let mode):
            switch mode {
            case .set:
                entry.progressNote = text
            case .append:
                if entry.progressNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    entry.progressNote = text
                } else {
                    entry.progressNote += "\n\n" + text
                }
            }
            selectedTab = .today
            writeSnapshotForToday()

        case .addCompletionNote(let text, let mode):
            switch mode {
            case .set:
                entry.completionNote = text
            case .append:
                if entry.completionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    entry.completionNote = text
                } else {
                    entry.completionNote += "\n\n" + text
                }
            }
            selectedTab = .today
            writeSnapshotForToday()

        case .completeTask(let slot, let value):
            applyCompletion(entry: entry, slot: slot, value: value)
            selectedTab = .today
            writeSnapshotForToday()
        }
    }

    private func applyCompletion(entry: DayEntry, slot: TaskSlot, value: CompletionValue) {
        func apply(current: Bool) -> Bool {
            switch value {
            case .true: return true
            case .false: return false
            case .toggle: return !current
            }
        }

        switch slot {
        case .one:
            entry.taskOneDone = apply(current: entry.taskOneDone)
        case .two:
            entry.taskTwoDone = apply(current: entry.taskTwoDone)
        case .three:
            entry.taskThreeDone = apply(current: entry.taskThreeDone)
        case .all:
            entry.taskOneDone = apply(current: entry.taskOneDone)
            entry.taskTwoDone = apply(current: entry.taskTwoDone)
            entry.taskThreeDone = apply(current: entry.taskThreeDone)
        }
    }

}

#Preview {
    ContentView()
        .modelContainer(for: [DayEntry.self, AppSettings.self], inMemory: true)
        .environment(DeepLinkRouter())
}
