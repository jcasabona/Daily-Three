//
//  ThemePalette.swift
//  Daily Three
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

#if os(iOS)
typealias PlatformColor = UIColor
#else
typealias PlatformColor = NSColor
#endif

struct ThemePalette {
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

    /// Text or icon color for content drawn on top of `accent`. White, unless the accent is so light
    /// (like the Sunrise yellow) that white would be unreadable.
    var onAccent: Color {
        dynamicColor(light: Self.contrastColor(for: palette.accentLight),
                     dark: Self.contrastColor(for: palette.accentDark))
    }

    private static func contrastColor(for color: PlatformColor) -> PlatformColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let brightness = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return brightness > 0.78 ? PlatformColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1) : PlatformColor.white
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
                backgroundLight: PlatformColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
                backgroundDark: PlatformColor(red: 0.16, green: 0.12, blue: 0.11, alpha: 1),
                accentLight: PlatformColor(red: 0.580, green: 0.502, blue: 0.278, alpha: 1),   // #948047: brand yellow #F7D677 darkened two 20% steps for contrast on white
                accentDark: PlatformColor(red: 0.969, green: 0.839, blue: 0.467, alpha: 1)
            )
        case .ocean:
            return ThemePaletteValues(
                backgroundLight: PlatformColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
                backgroundDark: PlatformColor(red: 0.09, green: 0.12, blue: 0.18, alpha: 1),
                accentLight: PlatformColor(red: 0.031, green: 0.173, blue: 0.271, alpha: 1),   // #082C45
                accentDark: PlatformColor(red: 0.46, green: 0.73, blue: 0.92, alpha: 1)
            )
        case .forest:
            return ThemePaletteValues(
                backgroundLight: PlatformColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
                backgroundDark: PlatformColor(red: 0.10, green: 0.14, blue: 0.11, alpha: 1),
                accentLight: PlatformColor(red: 0.18, green: 0.54, blue: 0.34, alpha: 1),
                accentDark: PlatformColor(red: 0.50, green: 0.78, blue: 0.60, alpha: 1)
            )
        case .graphite:
            return ThemePaletteValues(
                backgroundLight: PlatformColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
                backgroundDark: PlatformColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1),
                accentLight: PlatformColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1),   // #333333
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

extension ThemeOption {
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

extension AppearanceMode {
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
