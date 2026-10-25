//
//  WidgetTheme.swift
//  DailyThreeWidgetExtension
//
//  Theme colors and the small views shared by the widgets.
//

import WidgetKit
import SwiftUI
import AppIntents

#if os(iOS)
import UIKit
private typealias WidgetPlatformColor = UIColor
#elseif os(macOS)
import AppKit
private typealias WidgetPlatformColor = NSColor
#endif

// MARK: - Palette

/// The app's theme colors for widgets. This mirrors `ThemePalette` in the app target (the extension doesn't
/// compile that file), so keep the two in step when a theme changes.
struct WidgetPalette {
    let option: ThemeOption

    var background: Color {
        dynamic(light: WidgetPlatformColor(red: 1, green: 1, blue: 1, alpha: 1), dark: darkBackground)
    }

    var accent: Color {
        dynamic(light: accentLight, dark: accentDark)
    }

    /// Text and icons drawn on top of the accent. White, unless the accent is very light.
    var onAccent: Color {
        dynamic(light: contrastColor(for: accentLight), dark: contrastColor(for: accentDark))
    }

    /// A faint panel behind journal text.
    var panel: Color {
        dynamic(light: WidgetPlatformColor.black.withAlphaComponent(0.05), dark: WidgetPlatformColor.white.withAlphaComponent(0.08))
    }

    /// The unfilled part of a progress ring.
    var track: Color {
        dynamic(light: WidgetPlatformColor.black.withAlphaComponent(0.10), dark: WidgetPlatformColor.white.withAlphaComponent(0.16))
    }

    private var darkBackground: WidgetPlatformColor {
        switch option {
        case .sunrise: return WidgetPlatformColor(red: 0.16, green: 0.12, blue: 0.11, alpha: 1)
        case .ocean: return WidgetPlatformColor(red: 0.09, green: 0.12, blue: 0.18, alpha: 1)
        case .forest: return WidgetPlatformColor(red: 0.10, green: 0.14, blue: 0.11, alpha: 1)
        case .graphite: return WidgetPlatformColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1)
        }
    }

    private var accentLight: WidgetPlatformColor {
        switch option {
        case .sunrise: return WidgetPlatformColor(red: 0.580, green: 0.502, blue: 0.278, alpha: 1)
        case .ocean: return WidgetPlatformColor(red: 0.031, green: 0.173, blue: 0.271, alpha: 1)
        case .forest: return WidgetPlatformColor(red: 0.18, green: 0.54, blue: 0.34, alpha: 1)
        case .graphite: return WidgetPlatformColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        }
    }

    private var accentDark: WidgetPlatformColor {
        switch option {
        case .sunrise: return WidgetPlatformColor(red: 0.969, green: 0.839, blue: 0.467, alpha: 1)
        case .ocean: return WidgetPlatformColor(red: 0.46, green: 0.73, blue: 0.92, alpha: 1)
        case .forest: return WidgetPlatformColor(red: 0.50, green: 0.78, blue: 0.60, alpha: 1)
        case .graphite: return WidgetPlatformColor(red: 0.72, green: 0.73, blue: 0.76, alpha: 1)
        }
    }

    private func contrastColor(for color: WidgetPlatformColor) -> WidgetPlatformColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let brightness = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return brightness > 0.78 ? WidgetPlatformColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1) : .white
    }

    #if os(iOS)
    private func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
    #else
    private func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
    #endif
}

// MARK: - Shared views

/// A circular check: filled in the accent when done, an empty ring when not.
struct WidgetCheck: View {
    let isDone: Bool
    let palette: WidgetPalette
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            if isDone {
                Circle().fill(palette.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(palette.onAccent)
            } else {
                Circle().strokeBorder(.secondary.opacity(0.55), lineWidth: max(1.5, size * 0.09))
            }
        }
        .frame(width: size, height: size)
        .widgetAccentable(isDone)
    }
}

/// A ring that fills with progress, with any view in the middle.
struct WidgetProgressRing<Center: View>: View {
    let progress: Double
    let palette: WidgetPalette
    var lineWidth: CGFloat = 8
    @ViewBuilder var center: () -> Center

    var body: some View {
        ZStack {
            Circle().stroke(palette.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(palette.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
            center()
        }
        .padding(lineWidth / 2)
    }
}

/// One of the three tasks. Tapping it checks it off or on without opening the app.
struct TaskRowButton: View {
    let snapshot: DailySnapshot
    let index: Int
    let palette: WidgetPalette
    var checkSize: CGFloat = 20
    var fontSize: CGFloat = 14
    var lineLimit: Int = 2

    var body: some View {
        let text = snapshot.task(at: index)
        if text.isBlank {
            row(text: "Task \(index + 1)", isDone: false, isEmpty: true)
        } else {
            Button(intent: ToggleTaskIntent(index: index)) {
                row(text: text, isDone: snapshot.isDone(at: index), isEmpty: false)
            }
            .buttonStyle(.plain)
        }
    }

    private func row(text: String, isDone: Bool, isEmpty: Bool) -> some View {
        HStack(spacing: 8) {
            WidgetCheck(isDone: isDone, palette: palette, size: checkSize)
                .opacity(isEmpty ? 0.45 : 1)
            Text(text)
                .font(.system(size: fontSize, weight: .medium))
                .strikethrough(isDone, color: .secondary)
                .foregroundStyle(isEmpty || isDone ? .secondary : .primary)
                .lineLimit(lineLimit)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

/// A journal note. Tapping it opens the app at that note, since a widget can't take typing.
struct JournalBlock: View {
    let title: String
    let text: String
    let section: String
    let palette: WidgetPalette
    var lineLimit: Int = 3

    var body: some View {
        Link(destination: URL(string: "dailythree://journal?section=\(section)")!) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(palette.accent)
                    Spacer(minLength: 0)
                    if text.isBlank {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(text.isBlank ? "Tap to write" : text)
                    .font(.system(size: 12))
                    .foregroundStyle(text.isBlank ? .secondary : .primary)
                    .lineLimit(lineLimit)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(palette.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

/// Shown when no tasks are set for today.
struct EmptyTasksView: View {
    let palette: WidgetPalette
    var compact = false

    var body: some View {
        VStack(alignment: compact ? .leading : .center, spacing: 6) {
            Image(systemName: "checklist")
                .font(.system(size: compact ? 20 : 30, weight: .semibold))
                .foregroundStyle(palette.accent)
            Text("Add your three")
                .font(.system(size: compact ? 14 : 17, weight: .semibold, design: .serif))
            Text("Open Daily Three to set today's tasks.")
                .font(.system(size: compact ? 11 : 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(compact ? .leading : .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: compact ? .topLeading : .center)
    }
}

/// A serif section title, matching the app.
struct WidgetTitle: View {
    let text: String
    var size: CGFloat = 16

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .serif))
    }
}
