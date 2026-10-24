//
//  NotesCard.swift
//  Daily Three
//

import SwiftUI

struct NotesCard: View {
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
