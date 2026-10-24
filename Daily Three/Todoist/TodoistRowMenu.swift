//
//  TodoistRowMenu.swift
//  Daily Three
//
//  The small Todoist menu shown at the end of a task row.
//

import SwiftUI

/// What a task row needs to offer the Todoist menu.
struct TodoistRowControls {
    let isLinked: Bool
    let pick: () -> Void
    let unlink: () -> Void
}

struct TodoistRowMenu: View {
    let controls: TodoistRowControls
    let theme: ThemePalette

    var body: some View {
        Menu {
            Button("Choose from Todoist…", systemImage: "checklist") {
                controls.pick()
            }
            if controls.isLinked {
                Button("Unlink from Todoist", systemImage: "xmark", role: .destructive) {
                    controls.unlink()
                }
            }
        } label: {
            Image(systemName: controls.isLinked ? "link.circle.fill" : "link.circle")
                .font(.system(size: 17))
                .foregroundStyle(controls.isLinked ? theme.accent : theme.muted)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(controls.isLinked ? "Linked to Todoist" : "Link to Todoist")
    }
}
