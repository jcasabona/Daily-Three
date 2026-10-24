//
//  HeaderCard.swift
//  Daily Three
//

import SwiftUI

struct HeaderCard: View {
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
