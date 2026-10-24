//
//  TodoistSettingsSection.swift
//  Daily Three
//
//  Settings section for connecting Todoist and choosing how tasks sync.
//

import SwiftUI
import SwiftData

struct TodoistSettingsSection: View {
    @Bindable var settings: AppSettings
    @Environment(TodoistSyncService.self) private var todoist
    @Environment(\.modelContext) private var modelContext
    @State private var token = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var projects: [TodoistProject] = []

    var body: some View {
        Section {
            if todoist.isConnected {
                connectedContent
            } else {
                connectContent
            }
        } header: {
            Text("Todoist")
        } footer: {
            Text(footerText)
        }
        .alert("Todoist", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var footerText: String {
        if todoist.isConnected {
            return "Titles and completion stay in sync for today and upcoming days. The token is kept in this device's Keychain, so add it on each device you use."
        }
        return "In Todoist, open Settings → Integrations → Developer and copy your API token."
    }

    // MARK: - Not connected

    private var connectContent: some View {
        Group {
            SecureField("API token", text: $token)
                .textContentTypeIfAvailable()

            Button {
                connect()
            } label: {
                HStack(spacing: 8) {
                    Text("Connect")
                    if isConnecting { ProgressView().controlSize(.small) }
                }
            }
            .disabled(token.trimmed.isEmpty || isConnecting)

            Link("Open Todoist integration settings", destination: URL(string: "https://app.todoist.com/app/settings/integrations")!)
        }
    }

    private func connect() {
        isConnecting = true
        Task {
            defer { isConnecting = false }
            do {
                try await todoist.connect(token: token)
                token = ""
                await todoist.sync(context: modelContext, settings: settings)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // MARK: - Connected

    private var connectedContent: some View {
        Group {
            LabeledContent("Status") {
                statusView
            }

            Toggle("Create new tasks in Todoist", isOn: $settings.todoistCreatesTasks)

            if settings.todoistCreatesTasks {
                Picker("New tasks go to", selection: projectBinding) {
                    Text("Inbox").tag("")
                    ForEach(projects.filter { !$0.isInbox }) { project in
                        Text(project.name).tag(project.id)
                    }
                }
                .task { await loadProjects() }
            }

            Button("Sync Now") {
                Task { await todoist.sync(context: modelContext, settings: settings) }
            }
            .disabled(todoist.status == .syncing)

            Button("Disconnect", role: .destructive) {
                todoist.disconnect()
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch todoist.status {
        case .syncing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Syncing…").foregroundStyle(.secondary)
            }
        case .failed(let message):
            Text(message)
                .foregroundStyle(.red)
                .multilineTextAlignment(.trailing)
        case .idle:
            if let lastSync = todoist.lastSync {
                Text("Synced \(lastSync.formatted(.relative(presentation: .named)))")
                    .foregroundStyle(.secondary)
            } else {
                Text("Connected").foregroundStyle(.secondary)
            }
        }
    }

    private var projectBinding: Binding<String> {
        Binding(
            get: { settings.todoistProjectID },
            set: { newID in
                settings.todoistProjectID = newID
                settings.todoistProjectName = projects.first { $0.id == newID }?.name ?? ""
            }
        )
    }

    private func loadProjects() async {
        guard projects.isEmpty else { return }
        do {
            projects = try await todoist.projects()
        } catch {
            // The picker still offers the Inbox if the list can't load.
        }
    }
}

private extension View {
    /// Keeps the token field from offering autofill or autocapitalization.
    @ViewBuilder
    func textContentTypeIfAvailable() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never).autocorrectionDisabled()
        #else
        self.autocorrectionDisabled()
        #endif
    }
}
