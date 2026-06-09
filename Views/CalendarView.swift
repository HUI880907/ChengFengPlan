// MARK: - CalendarView.swift
// 乘风计划 - 日历视图

import SwiftUI

// MARK: - CalendarView

struct CalendarView: View {
    @Environment(TaskStore.self) private var taskStore
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var viewMode: ViewMode = .month
    @State private var showingAddTask = false
    @State private var lastTapDate: Date?
    @State private var lastTapTime: Date = Date()

    enum ViewMode: String, CaseIterable {
        case month = "月"
        case week = "周"
    }

    /// 获取指定日期是否有任务
    private func hasTasks(on date: Date) -> Bool {
        taskStore.tasks.contains { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: date)
        }
    }

    /// 获取指定日期的任务
    private func tasks(for date: Date) -> [TaskItem] {
        taskStore.tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: date)
        }
    }

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
        .sheet(isPresented: $showingAddTask) {
            AddEditTaskView(initialDueDate: selectedDate)
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
                        hasTask: hasTasks(on: date)
                    )
                    .onTapGesture {
                        handleDateTap(date)
                    }
                    .onLongPressGesture {
                        selectedDate = date
                        showingAddTask = true
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
                    hasTask: hasTasks(on: date)
                )
                .onTapGesture {
                    handleDateTap(date)
                }
                .onLongPressGesture {
                    selectedDate = date
                    showingAddTask = true
                }
            }
        }
    }

    // MARK: - Selected Date Tasks

    private var selectedDateTasks: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(DateFormatterCache.shared.format(selectedDate, style: .fullDate)) 的任务")
                    .font(.headline)

                Spacer()

                Button {
                    showingAddTask = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.themePrimary)
                }
            }
            .padding(.horizontal)

            let dateTasks = tasks(for: selectedDate)
            if dateTasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("当天暂无任务")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("双击日期或长按可快速添加任务")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(dateTasks) { task in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(task.priority.color)
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.body)
                                .foregroundStyle(task.status == .completed ? .secondary : .primary)
                                .strikethrough(task.status == .completed)

                            if !task.description.isEmpty {
                                Text(task.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Text(task.priority.displayName)
                            .font(.caption)
                            .foregroundStyle(task.priority.color)

                        if task.isOverdue {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }

            Spacer()
        }
    }

    // MARK: - Double Tap Handler

    private func handleDateTap(_ date: Date) {
        let now = Date()
        if let lastDate = lastTapDate,
           Calendar.current.isDate(lastDate, inSameDayAs: date),
           now.timeIntervalSince(lastTapTime) < 0.4 {
            // Double tap detected
            selectedDate = date
            showingAddTask = true
            lastTapDate = nil
            lastTapTime = Date.distantPast
        } else {
            selectedDate = date
            lastTapDate = date
            lastTapTime = now
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
        .environment(TaskStore.shared)
}
