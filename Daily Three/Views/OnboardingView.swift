//
//  OnboardingView.swift
//  Daily Three
//

import SwiftUI

struct OnboardingView: View {
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
                            .foregroundStyle(theme.onAccent)
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
