//
//  ContentView.swift
//  Daily Three
//
//  Created by Joe Casabona on 3/5/26.
//

import SwiftUI
import SwiftData
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

private enum AppTab: Hashable {
    case today
    case archive
    case settings
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \DayEntry.date, order: .reverse) private var entries: [DayEntry]
    @Query private var settingsList: [AppSettings]

    @State private var showingOnboarding = false
    @State private var selectedTab: AppTab = .today

    private var todayKey: String {
        DayEntry.makeDateKey(for: Date())
    }

    private var todayEntry: DayEntry? {
        entries.first { $0.dateKey == todayKey }
    }

    private var settings: AppSettings? {
        settingsList.first
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(
                entry: bindingForTodayEntry(),
                theme: currentTheme(),
                onSnapshotChange: writeSnapshotForToday,
                onTasksSetChange: scheduleNotificationsIfPossible
            )
                .tabItem {
                    Label("Today", systemImage: "checklist")
                }
                .tag(AppTab.today)

            ArchiveView(entries: entries, theme: currentTheme())
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
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            ensureSettings()
            requestNotificationsIfNeeded()
            writeSnapshotForToday()
            selectedTab = .today
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                selectedTab = .today
            }
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
        .onChange(of: settings?.theme) { _, _ in
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

    private func bindingForTodayEntry() -> Binding<DayEntry> {
        if let existing = todayEntry {
            return Binding(get: { existing }, set: { _ in })
        }

        let newEntry = DayEntry(date: Date())
        modelContext.insert(newEntry)
        return Binding(get: { newEntry }, set: { _ in })
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

}

private struct TodayView: View {
    @Binding var entry: DayEntry
    let theme: ThemePalette
    let onSnapshotChange: () -> Void
    let onTasksSetChange: () -> Void
    @State private var lastHasAllTasksSet: Bool?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HeaderCard(title: formattedDate(entry.date), subtitle: "Your three tasks", theme: theme)

                    TaskListCard(entry: $entry, theme: theme)

                    NotesCard(title: "Progress", prompt: "How are you progressing on your tasks?", text: $entry.progressNote, theme: theme)

                    NotesCard(title: "Completion", prompt: "Did you complete your tasks?", text: $entry.completionNote, theme: theme)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(theme.background)
            .navigationTitle("Daily Three")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Daily Three")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                }
            }
        }
        .onChange(of: entry.taskOne) { _, _ in
            onSnapshotChange()
            notifyTasksSetChangeIfNeeded()
        }
        .onChange(of: entry.taskTwo) { _, _ in
            onSnapshotChange()
            notifyTasksSetChangeIfNeeded()
        }
        .onChange(of: entry.taskThree) { _, _ in
            onSnapshotChange()
            notifyTasksSetChangeIfNeeded()
        }
        .onChange(of: entry.taskOneDone) { _, _ in onSnapshotChange() }
        .onChange(of: entry.taskTwoDone) { _, _ in onSnapshotChange() }
        .onChange(of: entry.taskThreeDone) { _, _ in onSnapshotChange() }
        .onChange(of: entry.progressNote) { _, _ in onSnapshotChange() }
        .onChange(of: entry.completionNote) { _, _ in onSnapshotChange() }
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

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Archive")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                }
            }
        }
        .tint(theme.accent)
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

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                }
            }
        }
        .tint(theme.accent)
        #if os(iOS)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Created by Joe Casabona with the help of Codex by OpenAI.")
                    .font(.system(.body, design: .serif))

                Link(destination: URL(string: "https://casabona.org/donate")!) {
                    Text("Donate")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)

                Link(destination: URL(string: "https://casabona.org/hire")!) {
                    Text("Hire me")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(theme.accent)

                Text(verbatim: "© \(Calendar.current.component(.year, from: Date())) Good House Media, LLC")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background(theme.background)
        .navigationTitle("Credits")
        .navigationBarTitleDisplayMode(.inline)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Daily Three")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                }
            }
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
    @State private var draggedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today’s Tasks")
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
                          showsDragHandle: isEditable)
            .contentShape(Rectangle())

        if isEditable {
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

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { isDone.toggle() }) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isDone ? theme.accent : theme.muted)
            }
            .buttonStyle(.plain)
            .disabled(!isEditable)

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

private struct ThemePalette {
    let option: ThemeOption

    var accent: Color {
        #if os(iOS)
        return dynamicColor(light: palette.accentLight, dark: palette.accentDark)
        #else
        return Color(nsColor: palette.accentLight)
        #endif
    }

    var background: Color {
        #if os(iOS)
        return dynamicColor(light: palette.backgroundLight, dark: palette.backgroundDark)
        #else
        return Color(nsColor: palette.backgroundLight)
        #endif
    }

    var card: Color {
        #if os(iOS)
        return dynamicColor(light: palette.cardLight, dark: palette.cardDark)
        #else
        return Color(nsColor: palette.cardLight)
        #endif
    }

    var field: Color {
        #if os(iOS)
        return dynamicColor(light: palette.fieldLight, dark: palette.fieldDark)
        #else
        return Color(nsColor: palette.fieldLight)
        #endif
    }

    var border: Color {
        #if os(iOS)
        return dynamicColor(light: palette.borderLight, dark: palette.borderDark)
        #else
        return Color(nsColor: palette.borderLight)
        #endif
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
        var cardDark: PlatformColor { PlatformColor.black.withAlphaComponent(0.4) }
        var fieldLight: PlatformColor { PlatformColor.white.withAlphaComponent(0.75) }
        var fieldDark: PlatformColor { PlatformColor.black.withAlphaComponent(0.5) }
        var borderLight: PlatformColor { PlatformColor.black.withAlphaComponent(0.12) }
        var borderDark: PlatformColor { PlatformColor.white.withAlphaComponent(0.18) }
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
}
