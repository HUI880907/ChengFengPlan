// MARK: - CalendarView.swift
// 乘风计划 - 日历视图

import SwiftUI

// MARK: - CalendarView

struct CalendarView: View {
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var viewMode: ViewMode = .month

    enum ViewMode: String, CaseIterable {
        case month = "月"
        case week = "周"
    }

    // 模拟有任务的日期
    private let taskDates: Set<Int> = [3, 5, 8, 12, 15, 18, 22, 25, 28]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: View Mode Picker
                Picker("视图", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // MARK: Calendar Header
                calendarHeader

                Divider()

                // MARK: Calendar Grid
                Group {
                    switch viewMode {
                    case .month:
                        monthGrid
                    case .week:
                        weekGrid
                    }
                }
                .padding(.horizontal)

                Divider()
                    .padding(.vertical, 8)

                // MARK: Selected Date Tasks
                selectedDateTasks
            }
            .navigationTitle("日历")
        }
    }

    // MARK: - Calendar Header

    private var calendarHeader: some View {
        HStack {
            Button {
                withAnimation {
                    currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(DateFormatterCache.shared.monthYearString(from: currentMonth))
                .font(.headline)

            Spacer()

            Button {
                withAnimation {
                    currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Month Grid

    private var monthGrid: some View {
        let days = daysInMonth(for: currentMonth)
        let columns = Array(repeating: GridItem(.flexible()), count: 7)

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(days, id: \.self) { date in
                if let date = date {
                    DayCell(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        hasTask: taskDates.contains(Calendar.current.component(.day, from: date))
                    )
                    .onTapGesture {
                        selectedDate = date
                    }
                } else {
                    Color.clear
                        .frame(height: 40)
                }
            }
        }
    }

    // MARK: - Week Grid

    private var weekGrid: some View {
        let weekDays = daysInWeek(for: selectedDate)
        let columns = Array(repeating: GridItem(.flexible()), count: 7)

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(weekDays, id: \.self) { date in
                DayCell(
                    date: date,
                    isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                    hasTask: taskDates.contains(Calendar.current.component(.day, from: date))
                )
                .onTapGesture {
                    selectedDate = date
                }
            }
        }
    }

    // MARK: - Selected Date Tasks

    private var selectedDateTasks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(DateFormatterCache.shared.format(selectedDate, style: .full)) 的任务")
                .font(.headline)
                .padding(.horizontal)

            if taskDates.contains(Calendar.current.component(.day, from: selectedDate)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("完成项目文档")
                        .font(.body)
                    Text("团队周会")
                        .font(.body)
                }
                .padding(.horizontal)
            } else {
                Text("当天暂无任务")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }

    // MARK: - Helper Methods

    private func daysInMonth(for date: Date) -> [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let daysInMonth = calendar.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day ?? 0

        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: monthInterval.start) {
                days.append(date)
            }
        }
        return days
    }

    private func daysInWeek(for date: Date) -> [Date] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }

        var days: [Date] = []
        for day in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: day, to: weekInterval.start) {
                days.append(date)
            }
        }
        return days
    }
}

// MARK: - DayCell

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let hasTask: Bool

    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Color.themePrimary)
                    .frame(width: 36, height: 36)
            } else if isToday {
                Circle()
                    .stroke(Color.themePrimary, lineWidth: 1)
                    .frame(width: 36, height: 36)
            }

            Text("\(dayNumber)")
                .font(.body)
                .foregroundStyle(isSelected ? .white : (isToday ? .themePrimary : .primary))
        }
        .frame(height: 40)
        .overlay(alignment: .bottom) {
            if hasTask {
                Circle()
                    .fill(isSelected ? .white : .themePrimary)
                    .frame(width: 4, height: 4)
                    .offset(y: -2)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarView()
}
