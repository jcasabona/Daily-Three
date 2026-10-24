//
//  AppIconSection.swift
//  Daily Three
//
//  Settings section for switching between the alternate app icons (iOS only).
//

#if os(iOS)
import SwiftUI
import UIKit

enum AppIconOption: String, CaseIterable, Identifiable {
    case automatic
    case black
    case sunrise
    case ocean
    case forest
    case graphite

    var id: String { rawValue }

    /// The asset-catalog name passed to `setAlternateIconName`. `nil` restores the primary icon.
    var alternateIconName: String? {
        self == .automatic ? nil : "AppIcon-\(rawValue.capitalized)"
    }

    /// Image set used for the thumbnail in the picker.
    var previewAssetName: String {
        "IconPreview-\(rawValue.capitalized)"
    }

    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .black: return "Black"
        case .sunrise: return "Sunrise"
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .graphite: return "Graphite"
        }
    }
}

struct AppIconSection: View {
    @State private var currentIconName = UIApplication.shared.alternateIconName
    @State private var errorMessage: String?

    var body: some View {
        Section {
            ForEach(AppIconOption.allCases) { option in
                Button {
                    select(option)
                } label: {
                    HStack(spacing: 12) {
                        Image(option.previewAssetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(.quaternary, lineWidth: 1)
                            )

                        Text(option.displayName)
                            .foregroundStyle(.primary)

                        Spacer()

                        if option.alternateIconName == currentIconName {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .accessibilityAddTraits(option.alternateIconName == currentIconName ? .isSelected : [])
            }
        } header: {
            Text("App Icon")
        } footer: {
            Text("Automatic follows light and dark mode. iOS shows a short notice whenever the icon changes.")
        }
        .alert("Couldn't change icon", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func select(_ option: AppIconOption) {
        guard option.alternateIconName != currentIconName else { return }
        guard UIApplication.shared.supportsAlternateIcons else {
            errorMessage = "This device doesn't support alternate app icons."
            return
        }

        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(option.alternateIconName)
                currentIconName = option.alternateIconName
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
#endif
