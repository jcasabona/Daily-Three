//
//  SettingsView.swift
//  Daily Three
//

import SwiftUI
import SwiftData
import WidgetKit
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var settings: AppSettings
    let theme: ThemePalette
    @Query(sort: \DayEntry.date) private var entries: [DayEntry]
    @State private var isShowingImporter = false
    @State private var importMessage: String?
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

    /// Weekdays starting from the user's first day of the week.
    private var orderedWeekdays: [(number: Int, name: String)] {
        let calendar = Calendar.current
        let symbols = calendar.weekdaySymbols
        return (0..<7).map { offset in
            let index = (calendar.firstWeekday - 1 + offset) % 7
            return (number: index + 1, name: symbols[index])
        }
    }

    private func weekdayBinding(_ number: Int) -> Binding<Bool> {
        Binding(
            get: { !settings.excludedWeekdays.contains(number) },
            set: { isActive in
                var excluded = settings.excludedWeekdays
                if isActive {
                    excluded.remove(number)
                } else {
                    excluded.insert(number)
                }
                settings.excludedWeekdays = excluded
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

            Section {
                ForEach(orderedWeekdays, id: \.number) { weekday in
                    Toggle(weekday.name, isOn: weekdayBinding(weekday.number))
                }
            } header: {
                Text("Active Days")
            } footer: {
                Text("Turned-off days are hidden from the planner and won't send prompts.")
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

            #if os(iOS)
            AppIconSection()
            #endif

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

            Section {
                Button {
                    isShowingImporter = true
                } label: {
                    Label("Import CSV", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Import")
            } footer: {
                Text("Import a file from Export CSV. Days that already exist are merged, never overwritten.")
            }

            Section("Credits") {
                NavigationLink("Credits") {
                    CreditsView(theme: theme)
                }
            }
        }
        .fileImporter(isPresented: $isShowingImporter, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            handleImport(result)
        }
        .alert("Import", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importMessage ?? "")
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            importMessage = "Couldn't open the file: \(error.localizedDescription)"
        case .success(let url):
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let summary = try CSVImporter.importCSV(String(decoding: data, as: UTF8.self), into: modelContext)
                WidgetCenter.shared.reloadAllTimelines()
                importMessage = summary.description
            } catch {
                importMessage = error.localizedDescription
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
            .formStyle(.grouped)
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

#if os(iOS)
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
