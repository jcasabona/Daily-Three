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
    @Environment(TodoistSyncService.self) private var todoist
    @Query(sort: \DayEntry.date, order: .reverse) private var entries: [DayEntry]
    @Query private var settingsList: [AppSettings]

    @State private var showingOnboarding = false
    @State private var selectedTab: AppTab = .today
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    /// Set by the widgets' Journal buttons; Today moves to and focuses that note, then clears it.
    @State private var focusedJournal: JournalSection?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

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

    private var sidebarSelection: Binding<AppTab?> {
        Binding(get: { selectedTab }, set: { if let tab = $0 { selectedTab = tab } })
    }

    private var sidebar: some View {
        List(selection: sidebarSelection) {
            Section {
                Label {
                    Text("Today")
                } icon: {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                }
                .tag(AppTab.today)

                Label {
                    Text("Archive")
                } icon: {
                    Image(systemName: "books.vertical.fill").foregroundStyle(.green)
                }
                .tag(AppTab.archive)
            }

            Section {
                Label {
                    Text("Settings")
                } icon: {
                    Image(systemName: "gearshape.fill").foregroundStyle(.gray)
                }
                .tag(AppTab.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
    }

    private var sidebarContainer: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            Group {
                switch selectedTab {
                case .today:
                    TodayView(
                        entry: bindingForEntry(on: selectedDate),
                        theme: currentTheme(),
                        editingMode: editingMode,
                        selectableDates: selectableDates,
                        selectedDate: $selectedDate,
                        focusedJournal: $focusedJournal,
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
            #if os(macOS)
            .toolbar(removing: .title)
            #endif
        }
        .navigationSplitViewStyle(.balanced)
        .environment(\.surfaceStyle, .flat)
        .environment(\.usesSidebar, true)
        .tint(currentTheme().accent)
    }

    private var tabContainer: some View {
        TabView(selection: $selectedTab) {
            TodayView(
                entry: bindingForEntry(on: selectedDate),
                theme: currentTheme(),
                editingMode: editingMode,
                selectableDates: selectableDates,
                selectedDate: $selectedDate,
                focusedJournal: $focusedJournal,
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
        .environment(\.surfaceStyle, .flat)
        .tint(currentTheme().accent)
    }

    #if os(iOS)
    /// iPads 11" and up get the Mac's sidebar layout; iPhones and smaller or narrow iPad windows keep the tab bar.
    private var usesSidebar: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
            && horizontalSizeClass == .regular
            && shortScreenSide >= 820
    }

    /// The shorter side of the screen this app is on, whatever size its window is.
    private var shortScreenSide: CGFloat {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let bounds = scene?.screen.bounds else { return 0 }
        return min(bounds.width, bounds.height)
    }

    @ViewBuilder
    private var mainContainer: some View {
        if usesSidebar { sidebarContainer } else { tabContainer }
    }
    #else
    private var mainContainer: some View { sidebarContainer }
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
        // Sync shortly after an edit (the pause means typing doesn't send a request per keystroke),
        // and again whenever the app comes to the foreground or Todoist gets connected.
        .task(id: todoistSyncSignature) {
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            await syncTodoist()
        }
        // While the app stays open, pick up changes made in Todoist.
        .task(id: scenePhase) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(120))
                guard !Task.isCancelled else { return }
                await syncTodoist()
            }
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

    /// Changes whenever something Todoist cares about changes, so a sync can follow an edit.
    private var todoistSyncSignature: String {
        let slots = entries
            .filter { $0.dateKey >= todayKey }
            .map { entry in
                (0..<DayEntry.slotCount).map { slot in
                    "\(entry.text(in: slot))|\(entry.isDone(in: slot))|\(entry.todoistLink(in: slot).taskID)"
                }.joined(separator: ";")
            }
            .joined(separator: "#")
        return "\(todoist.isConnected)|\(scenePhase == .active)|\(settings?.todoistCreatesTasks ?? true)|\(settings?.todoistProjectID ?? "")|\(slots)"
    }

    private func syncTodoist() async {
        guard todoist.isConnected, scenePhase == .active else { return }
        await todoist.sync(context: modelContext, settings: settings)
    }

    private func scheduleNotificationsIfPossible() {
        guard let settings else { return }
        NotificationScheduler.shared.scheduleDailyNotifications(with: settings, entry: todayEntry)
    }

    private func currentTheme() -> ThemePalette {
        let option = settings?.theme ?? .graphite
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

        case .openJournal(let section):
            selectedTab = .today
            selectedDate = Calendar.current.startOfDay(for: Date())
            focusedJournal = section

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
        .environment(TodoistSyncService())
}

