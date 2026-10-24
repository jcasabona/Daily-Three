//
//  DateSelector.swift
//  Daily Three
//

import SwiftUI

struct DateSelectorBar: View {
    let dates: [Date]
    @Binding var selectedDate: Date
    let theme: ThemePalette

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(dates, id: \.self) { date in
                    DateChip(date: date, isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate), isToday: Calendar.current.isDateInToday(date), theme: theme)
                        .onTapGesture { selectedDate = date }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
    }
}

private struct DateChip: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let theme: ThemePalette

    private var weekday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(weekday)
                .font(.system(size: 11, weight: .semibold, design: .serif))
            Text(dayNumber)
                .font(.system(size: 16, weight: .bold, design: .serif))
        }
        .frame(width: 44, height: 52)
        .background(isSelected ? theme.accent : theme.card)
        .foregroundStyle(isSelected ? theme.onAccent : .primary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isToday && !isSelected ? theme.accent : theme.border, lineWidth: isToday && !isSelected ? 2 : 1)
        )
    }
}
