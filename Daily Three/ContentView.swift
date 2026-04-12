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
import UserNotifications
import WidgetKit
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

#if os(iOS)
private typealias PlatformColor = UIColor
#else
private typealias PlatformColor = NSColor
#endif

extension View {
    @ViewBuilder
    func inlineNavigationBarTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

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

private enum DayEditingMode {
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
        return (0...7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
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

private struct TodayView: View {
    @Binding var entry: DayEntry
    let theme: ThemePalette
    let editingMode: DayEditingMode
    let selectableDates: [Date]
    @Binding var selectedDate: Date
    let onSnapshotChange: () -> Void
    let onTasksSetChange: () -> Void
    @State private var lastHasAllTasksSet: Bool?

    private var subtitle: String {
        editingMode == .today ? "Your three tasks" : "Plan ahead"
    }

    private var showCheckboxes: Bool {
        editingMode == .today
    }

    private var showDragHandles: Bool {
        editingMode == .today
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DateSelectorBar(dates: selectableDates, selectedDate: $selectedDate, theme: theme)

                HeaderCard(title: formattedDate(entry.date), subtitle: subtitle, theme: theme)

                TaskListCard(entry: $entry, theme: theme, isEditable: editingMode != .readOnly, showCheckboxes: showCheckboxes, showDragHandles: showDragHandles)

                if editingMode == .today {
                    NotesCard(title: "Progress", prompt: "How are you progressing on your tasks?", text: $entry.progressNote, theme: theme)

                    NotesCard(title: "Completion", prompt: "Did you complete your tasks?", text: $entry.completionNote, theme: theme)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    #if os(iOS)
    private var viewContainer: some View {
        NavigationStack {
            scrollContent
                .background(theme.background)
                .navigationTitle("Daily Three")
                .inlineNavigationBarTitle()
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Daily Three")
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                    }
                }
        }
    }
    #else
    private var viewContainer: some View {
        scrollContent
            .padding(.top, 12)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
            .background(theme.background)
    }
    #endif

    var body: some View {
        viewContainer
        .onChange(of: entry.taskOne) { _, _ in
            onSnapshotChange()
            if editingMode == .today { notifyTasksSetChangeIfNeeded() }
        }
        .onChange(of: entry.taskTwo) { _, _ in
            onSnapshotChange()
            if editingMode == .today { notifyTasksSetChangeIfNeeded() }
        }
        .onChange(of: entry.taskThree) { _, _ in
            onSnapshotChange()
            if editingMode == .today { notifyTasksSetChangeIfNeeded() }
        }
        .onChange(of: entry.taskOneDone) { _, _ in
            if editingMode == .today { onSnapshotChange() }
        }
        .onChange(of: entry.taskTwoDone) { _, _ in
            if editingMode == .today { onSnapshotChange() }
        }
        .onChange(of: entry.taskThreeDone) { _, _ in
            if editingMode == .today { onSnapshotChange() }
        }
        .onChange(of: entry.progressNote) { _, _ in
            if editingMode == .today { onSnapshotChange() }
        }
        .onChange(of: entry.completionNote) { _, _ in
            if editingMode == .today { onSnapshotChange() }
        }
        .onAppear {
            lastHasAllTasksSet = entry.hasAllTasksSet
        }
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .complete, time: .omitted)
    }

    private func notifyTasksSetChangeIfNeeded() {
        let current = entry.hasAllTasksSet
        guard lastHasAllTasksSet != current else { return }
        lastHasAllTasksSet = current
        onTasksSetChange()
    }
}

private struct ArchiveView: View {
    let entries: [DayEntry]
    let theme: ThemePalette

    private var listContent: some View {
        List {
            ForEach(entries) { entry in
                NavigationLink {
                    ArchiveDetailView(entry: entry, theme: theme)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.date.formatted(date: .complete, time: .omitted))
                            .font(.headline)
                        Text(summary(for: entry))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            listContent
                .navigationTitle("Archive")
                .inlineNavigationBarTitle()
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Archive")
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                    }
                }
        }
        .tint(theme.accent)
        #else
        listContent
            .tint(theme.accent)
        #endif
    }

    private func summary(for entry: DayEntry) -> String {
        let completed = [entry.taskOneDone, entry.taskTwoDone, entry.taskThreeDone].filter { $0 }.count
        return "\(completed) of 3 completed"
    }
}

private struct ArchiveDetailView: View {
    @Bindable var entry: DayEntry
    let theme: ThemePalette

    var body: some View {
        let entryBinding = Binding<DayEntry>(get: { entry }, set: { _ in })
        let progressBinding = Binding<String>(get: { entry.progressNote }, set: { _ in })
        let completionBinding = Binding<String>(get: { entry.completionNote }, set: { _ in })
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderCard(title: entry.date.formatted(date: .complete, time: .omitted), subtitle: "Snapshot", theme: theme)

                TaskListCard(entry: entryBinding, theme: theme, isEditable: false)

                if !entry.progressNote.isEmpty {
                    NotesCard(title: "Progress", prompt: "", text: progressBinding, theme: theme, isEditable: false)
                }

                if !entry.completionNote.isEmpty {
                    NotesCard(title: "Completion", prompt: "", text: completionBinding, theme: theme, isEditable: false)
                }
            }
            .padding(16)
        }
        .background(theme.background)
        .navigationTitle("Details")
    }
}

private struct SettingsView: View {
    @Bindable var settings: AppSettings
    let theme: ThemePalette
    @Query(sort: \DayEntry.date) private var entries: [DayEntry]
    @State private var isExportingCSV = false
    @State private var isPresentingShareSheet = false
    @State private var exportURL: URL?

    private var onboardingResetBinding: Binding<Bool> {
        Binding(
            get: { !(settings.hasCompletedOnboarding ?? false) },
            set: { newValue in
                settings.hasCompletedOnboarding = !newValue
            }
        )
    }

    private var formContent: some View {
        Form {
            Section("Prompt Times") {
                DatePicker("Morning Prompt", selection: $settings.morningTime, displayedComponents: .hourAndMinute)
                DatePicker("Midday Prompt", selection: $settings.middayTime, displayedComponents: .hourAndMinute)
                DatePicker("Evening Prompt", selection: $settings.eveningTime, displayedComponents: .hourAndMinute)
            }

            Section("Theme") {
                Picker("Theme", selection: $settings.theme) {
                    ForEach(ThemeOption.allCases, id: \.self) { option in
                        Label {
                            Text(option.displayName)
                        } icon: {
                            Circle()
                                .fill(ThemePalette(option: option).accent)
                                .frame(width: 15, height: 15)
                        }
                        .tag(option)
                    }
                }
                .pickerStyle(.inline)
            }

            Section("Appearance") {
                Picker("App Appearance", selection: $settings.appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Onboarding") {
                Toggle("Reset onboarding", isOn: onboardingResetBinding)
            }

            Section("Export") {
                #if os(iOS)
                Button {
                    startExport()
                } label: {
                    HStack(spacing: 8) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                        if isExportingCSV {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(isExportingCSV)
                #else
                ShareLink(item: makeCSVFileURL()) {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                #endif
            }

            Section("Credits") {
                NavigationLink("Credits") {
                    CreditsView(theme: theme)
                }
            }
        }
    }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            formContent
                .navigationTitle("Settings")
                .inlineNavigationBarTitle()
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Settings")
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                    }
                }
        }
        .tint(theme.accent)
        .sheet(isPresented: $isPresentingShareSheet, onDismiss: {
            isExportingCSV = false
            exportURL = nil
        }) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
                    .onAppear {
                        isExportingCSV = false
                    }
            } else {
                ProgressView()
            }
        }
        #else
        formContent
            .tint(theme.accent)
        #endif
    }

    private func makeCSV() -> String {
        var lines = ["date,task_one,task_two,task_three,task_one_done,task_two_done,task_three_done,progress_note,completion_note"]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        for entry in entries {
            let row = [
                formatter.string(from: entry.date),
                entry.taskOne,
                entry.taskTwo,
                entry.taskThree,
                entry.taskOneDone ? "true" : "false",
                entry.taskTwoDone ? "true" : "false",
                entry.taskThreeDone ? "true" : "false",
                entry.progressNote,
                entry.completionNote
            ]
            .map { escapeCSV($0) }
            .joined(separator: ",")
            lines.append(row)
        }

        return lines.joined(separator: "\n")
    }

    private func makeCSVFileURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "DailyThree-Export-\(formatter.string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try makeCSV().write(to: url, atomically: true, encoding: .utf8)
        } catch {
            // Return the URL even if writing fails; share sheet will handle missing data.
        }

        return url
    }

    private func startExport() {
        guard !isExportingCSV else { return }
        isExportingCSV = true
        exportURL = makeCSVFileURL()
        isPresentingShareSheet = true
    }

    private func escapeCSV(_ value: String) -> String {
        let needsQuotes = value.contains(",") || value.contains("\n") || value.contains("\"")
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuotes ? "\"\(escaped)\"" : escaped
    }
}

private struct CSVExport: Transferable {
    let csv: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .commaSeparatedText) { export in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let filename = "DailyThree-Export-\(formatter.string(from: Date())).csv"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try export.csv.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        } importing: { received in
            let data = try Data(contentsOf: received.file)
            let csv = String(decoding: data, as: UTF8.self)
            return CSVExport(csv: csv)
        }
    }
}

#if os(iOS)
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

private struct CreditsView: View {
    let theme: ThemePalette

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Created by Joe Casabona with the help of Claude Code. Initial codebase by Codex by OpenAI.")
                .font(.system(.body, design: .serif))
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Link(destination: URL(string: "https://casabona.org/hire")!) {
                    Text("Hire Me")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)

                Link(destination: URL(string: "https://casabona.org/donate")!) {
                    Text("☕ Donate")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(theme.accent)
            }

            Spacer()

            Text(verbatim: "© \(Calendar.current.component(.year, from: Date())) Good House Media, LLC")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .navigationTitle("Credits")
        .inlineNavigationBarTitle()
    }
}

private struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: AppSettings
    @Binding var entry: DayEntry
    let theme: ThemePalette
    let onSnapshotChange: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HeaderCard(title: "Welcome", subtitle: "Set your day up in minutes", theme: theme)

                    Group {
                        SectionTitle(text: "Set your times")
                        DatePicker("Morning Prompt", selection: $settings.morningTime, displayedComponents: .hourAndMinute)
                        DatePicker("Midday Prompt", selection: $settings.middayTime, displayedComponents: .hourAndMinute)
                        DatePicker("Evening Prompt", selection: $settings.eveningTime, displayedComponents: .hourAndMinute)
                    }

                    Group {
                        SectionTitle(text: "Pick your theme")
                        ThemePicker(selection: $settings.theme, theme: theme)
                    }

                    Group {
                        SectionTitle(text: "Appearance")
                        AppearancePicker(selection: $settings.appearanceMode, theme: theme)
                    }

                    Group {
                        SectionTitle(text: "Add your tasks for today")
                        TaskEditorRow(title: "Task 1", text: $entry.taskOne, theme: theme)
                        TaskEditorRow(title: "Task 2", text: $entry.taskTwo, theme: theme)
                        TaskEditorRow(title: "Task 3", text: $entry.taskThree, theme: theme)
                    }

                    Button(action: {
                        settings.hasCompletedOnboarding = true
                        onSnapshotChange()
                        dismiss()
                    }) {
                        Text("Start Today")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                }
                .padding(20)
            }
            .background(theme.background)
            .navigationTitle("Daily Three")
            #if os(iOS)
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Daily Three")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                }
            }
            #endif
        }
        .tint(theme.accent)
        .onChange(of: entry.taskOne) { _, _ in onSnapshotChange() }
        .onChange(of: entry.taskTwo) { _, _ in onSnapshotChange() }
        .onChange(of: entry.taskThree) { _, _ in onSnapshotChange() }
    }
}

private struct HeaderCard: View {
    let title: String
    let subtitle: String
    let theme: ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .serif))
            Text(subtitle)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }
}

private struct TaskListCard: View {
    @Binding var entry: DayEntry
    let theme: ThemePalette
    var isEditable: Bool = true
    var showCheckboxes: Bool = true
    var showDragHandles: Bool = true
    @State private var draggedIndex: Int?

    private var cardTitle: String {
        showCheckboxes ? "Today's Tasks" : "Tasks"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(cardTitle)
                .font(.system(.headline, design: .serif))

            ForEach(0..<3, id: \.self) { index in
                taskRowView(index: index)
            }
        }
        .padding(16)
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func taskRowView(index: Int) -> some View {
        let row = TaskRow(title: taskTitle(for: index),
                          text: textBinding(for: index),
                          isDone: doneBinding(for: index),
                          isEditable: isEditable,
                          theme: theme,
                          showsDragHandle: showDragHandles,
                          showCheckbox: showCheckboxes)
            .contentShape(Rectangle())

        if showDragHandles {
            row
                .onDrag {
                    draggedIndex = index
                    return NSItemProvider(item: nil, typeIdentifier: UTType.data.identifier)
                }
                .onDrop(of: [UTType.data], delegate: TaskDropDelegate(destinationIndex: index,
                                                                     draggedIndex: $draggedIndex,
                                                                     entry: $entry))
        } else {
            row
        }
    }

    private func taskTitle(for index: Int) -> String {
        switch index {
        case 0: return "Task 1"
        case 1: return "Task 2"
        default: return "Task 3"
        }
    }

    private func textBinding(for index: Int) -> Binding<String> {
        Binding(get: { taskText(for: index) }, set: { setTaskText(for: index, value: $0) })
    }

    private func doneBinding(for index: Int) -> Binding<Bool> {
        Binding(get: { taskDone(for: index) }, set: { setTaskDone(for: index, value: $0) })
    }

    private func taskText(for index: Int) -> String {
        switch index {
        case 0: return entry.taskOne
        case 1: return entry.taskTwo
        default: return entry.taskThree
        }
    }

    private func taskDone(for index: Int) -> Bool {
        switch index {
        case 0: return entry.taskOneDone
        case 1: return entry.taskTwoDone
        default: return entry.taskThreeDone
        }
    }

    private func setTaskText(for index: Int, value: String) {
        switch index {
        case 0: entry.taskOne = value
        case 1: entry.taskTwo = value
        default: entry.taskThree = value
        }
    }

    private func setTaskDone(for index: Int, value: Bool) {
        switch index {
        case 0: entry.taskOneDone = value
        case 1: entry.taskTwoDone = value
        default: entry.taskThreeDone = value
        }
    }
}

private struct TaskRow: View {
    let title: String
    @Binding var text: String
    @Binding var isDone: Bool
    let isEditable: Bool
    let theme: ThemePalette
    var showsDragHandle: Bool = false
    var showCheckbox: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            if showCheckbox {
                Button(action: { isDone.toggle() }) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isDone ? theme.accent : theme.muted)
                }
                .buttonStyle(.plain)
                .disabled(!isEditable)
            }

            if isEditable {
                TextField(title, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .regular, design: .serif))
            } else {
                Text(text.isEmpty ? title : text)
                    .foregroundStyle(text.isEmpty ? .secondary : .primary)
                    .font(.system(size: 17, weight: .regular, design: .serif))
            }
        }
        .padding(12)
        .background(theme.field)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .overlay(alignment: .trailing) {
            if showsDragHandle {
                Image(systemName: "line.3.horizontal")
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .padding(.trailing, 8)
            }
        }
    }
}

private struct TaskDropDelegate: DropDelegate {
    let destinationIndex: Int
    @Binding var draggedIndex: Int?
    @Binding var entry: DayEntry

    func dropEntered(info: DropInfo) {
        guard let draggedIndex, draggedIndex != destinationIndex else { return }
        swapTasks(from: draggedIndex, to: destinationIndex)
        self.draggedIndex = destinationIndex
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedIndex = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    private func swapTasks(from: Int, to: Int) {
        let source = taskPair(for: from)
        let destination = taskPair(for: to)
        setTask(for: from, text: destination.text, done: destination.done)
        setTask(for: to, text: source.text, done: source.done)
    }

    private func taskPair(for index: Int) -> (text: String, done: Bool) {
        switch index {
        case 0:
            return (entry.taskOne, entry.taskOneDone)
        case 1:
            return (entry.taskTwo, entry.taskTwoDone)
        default:
            return (entry.taskThree, entry.taskThreeDone)
        }
    }

    private func setTask(for index: Int, text: String, done: Bool) {
        switch index {
        case 0:
            entry.taskOne = text
            entry.taskOneDone = done
        case 1:
            entry.taskTwo = text
            entry.taskTwoDone = done
        default:
            entry.taskThree = text
            entry.taskThreeDone = done
        }
    }
}

private struct TaskEditorRow: View {
    let title: String
    @Binding var text: String
    let theme: ThemePalette

    var body: some View {
        TextField(title, text: $text)
            .textFieldStyle(.plain)
            .padding(12)
            .background(theme.field)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
    }
}

private struct NotesCard: View {
    let title: String
    let prompt: String
    @Binding var text: String
    let theme: ThemePalette
    var isEditable: Bool = true
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(.headline, design: .serif))
                Spacer()
                if isEditable && isFocused {
                    Button("Done") {
                        isFocused = false
                        dismissKeyboard()
                    }
                    .font(.system(.subheadline, design: .serif))
                    .buttonStyle(.bordered)
                    .tint(theme.accent)
                }
            }

            if !prompt.isEmpty {
                Text(prompt)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(.secondary)
            }

            if isEditable {
                TextEditor(text: $text)
                    .focused($isFocused)
                    .frame(minHeight: 90)
                    .padding(8)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .scrollContentBackground(.hidden)
                    .background(theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
            } else {
                Text(text)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    #if os(iOS)
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    #else
    private func dismissKeyboard() { }
    #endif
}

private struct ThemePicker: View {
    @Binding var selection: ThemeOption
    let theme: ThemePalette

    var body: some View {
        VStack(spacing: 12) {
            ForEach(ThemeOption.allCases, id: \.self) { option in
                Button(action: { selection = option }) {
                    HStack {
                        Circle()
                            .fill(ThemePalette(option: option).accent)
                            .frame(width: 18, height: 18)
                        Text(option.displayName)
                        Spacer()
                        if selection == option {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    .padding(12)
                    .background(theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct AppearancePicker: View {
    @Binding var selection: AppearanceMode
    let theme: ThemePalette

    var body: some View {
        HStack(spacing: 12) {
            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                Button(action: { selection = mode }) {
                    Text(mode.displayName)
                        .font(.system(.subheadline, design: .serif))
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(theme.field)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(selection == mode ? theme.accent : theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.headline, design: .serif))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DateSelectorBar: View {
    let dates: [Date]
    @Binding var selectedDate: Date
    let theme: ThemePalette

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(dates, id: \.self) { date in
                    DateChip(date: date, isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate), isToday: Calendar.current.isDateInToday(date), theme: theme)
                        .onTapGesture { selectedDate = date }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
    }
}

private struct DateChip: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let theme: ThemePalette

    private var weekday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(weekday)
                .font(.system(size: 11, weight: .semibold, design: .serif))
            Text(dayNumber)
                .font(.system(size: 16, weight: .bold, design: .serif))
        }
        .frame(width: 44, height: 52)
        .background(isSelected ? theme.accent : theme.card)
        .foregroundStyle(isSelected ? .white : .primary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isToday && !isSelected ? theme.accent : theme.border, lineWidth: isToday && !isSelected ? 2 : 1)
        )
    }
}

private struct ThemePalette {
    let option: ThemeOption

    var accent: Color {
        dynamicColor(light: palette.accentLight, dark: palette.accentDark)
    }

    var background: Color {
        dynamicColor(light: palette.backgroundLight, dark: palette.backgroundDark)
    }

    var card: Color {
        dynamicColor(light: palette.cardLight, dark: palette.cardDark)
    }

    var field: Color {
        dynamicColor(light: palette.fieldLight, dark: palette.fieldDark)
    }

    var border: Color {
        dynamicColor(light: palette.borderLight, dark: palette.borderDark)
    }

    var muted: Color {
        Color.secondary
    }

    #if os(iOS)
    private func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
    #else
    private func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
    #endif

    private var palette: ThemePaletteValues {
        switch option {
        case .sunrise:
            return ThemePaletteValues(
                backgroundLight: PlatformColor(red: 0.99, green: 0.95, blue: 0.90, alpha: 1),
                backgroundDark: PlatformColor(red: 0.16, green: 0.12, blue: 0.11, alpha: 1),
                accentLight: PlatformColor(red: 0.95, green: 0.48, blue: 0.30, alpha: 1),
                accentDark: PlatformColor(red: 0.99, green: 0.67, blue: 0.44, alpha: 1)
            )
        case .ocean:
            return ThemePaletteValues(
                backgroundLight: PlatformColor(red: 0.91, green: 0.96, blue: 0.99, alpha: 1),
                backgroundDark: PlatformColor(red: 0.09, green: 0.12, blue: 0.18, alpha: 1),
                accentLight: PlatformColor(red: 0.16, green: 0.47, blue: 0.78, alpha: 1),
                accentDark: PlatformColor(red: 0.46, green: 0.73, blue: 0.92, alpha: 1)
            )
        case .forest:
            return ThemePaletteValues(
                backgroundLight: PlatformColor(red: 0.92, green: 0.97, blue: 0.93, alpha: 1),
                backgroundDark: PlatformColor(red: 0.10, green: 0.14, blue: 0.11, alpha: 1),
                accentLight: PlatformColor(red: 0.18, green: 0.54, blue: 0.34, alpha: 1),
                accentDark: PlatformColor(red: 0.50, green: 0.78, blue: 0.60, alpha: 1)
            )
        case .graphite:
            return ThemePaletteValues(
                backgroundLight: PlatformColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1),
                backgroundDark: PlatformColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1),
                accentLight: PlatformColor(red: 0.32, green: 0.33, blue: 0.36, alpha: 1),
                accentDark: PlatformColor(red: 0.72, green: 0.73, blue: 0.76, alpha: 1)
            )
        }
    }

    private struct ThemePaletteValues {
        let backgroundLight: PlatformColor
        let backgroundDark: PlatformColor
        let accentLight: PlatformColor
        let accentDark: PlatformColor

        var cardLight: PlatformColor { backgroundLight.withAlphaComponent(0.8) }
        var cardDark: PlatformColor { PlatformColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1) }
        var fieldLight: PlatformColor { PlatformColor.white.withAlphaComponent(0.75) }
        var fieldDark: PlatformColor { PlatformColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1) }
        var borderLight: PlatformColor { PlatformColor.black.withAlphaComponent(0.12) }
        var borderDark: PlatformColor { PlatformColor.white.withAlphaComponent(0.12) }
    }
}

private final class NotificationScheduler {
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

        center.removePendingNotificationRequests(withIdentifiers: requests.map { $0.identifier })

        for request in requests {
            let content = UNMutableNotificationContent()
            content.title = request.title
            content.body = request.body
            content.sound = .default

            let components = Calendar.current.dateComponents([.hour, .minute], from: request.time)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let notification = UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger)
            center.add(notification)
        }
    }
}

private struct NotificationRequest {
    let identifier: String
    let time: Date
    let title: String
    let body: String
}

private extension DayEntry {
    var hasAllTasksSet: Bool {
        !taskOne.trimmed.isEmpty && !taskTwo.trimmed.isEmpty && !taskThree.trimmed.isEmpty
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension ThemeOption {
    var displayName: String {
        switch self {
        case .sunrise:
            return "Sunrise"
        case .ocean:
            return "Ocean"
        case .forest:
            return "Forest"
        case .graphite:
            return "Graphite"
        }
    }
}

private extension AppearanceMode {
    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [DayEntry.self, AppSettings.self], inMemory: true)
        .environment(DeepLinkRouter())
}
