// MARK: - StatisticsView.swift
// 乘风计划 - 统计分析视图

import SwiftUI
import Charts

// MARK: - StatisticsView

struct StatisticsView: View {
    @Environment(TaskStore.self) private var taskStore
    @State private var timeRange: TimeRange = .week

    enum TimeRange: String, CaseIterable {
        case week = "本周"
        case month = "本月"
        case year = "本年"
    }

    // MARK: - Computed Statistics from TaskStore

    private var totalTasks: Int {
        taskStore.tasks.count
    }

    private var completedTasks: [TaskItem] {
        taskStore.tasks.filter { $0.status == .completed }
    }

    private var completionRate: String {
        guard totalTasks > 0 else { return "0%" }
        return "\(Int(Double(completedTasks.count) / Double(totalTasks) * 100))%"
    }

    private var overdueCount: Int {
        taskStore.getOverdueTasks().count
    }

    private var completionData: [CompletionData] {
        let calendar = Calendar.current
        let now = Date()
        var data: [CompletionData] = []

        let dayCount: Int
        switch timeRange {
        case .week: dayCount = 7
        case .month: dayCount = 30
        case .year: dayCount = 365
        }

        for i in stride(from: dayCount - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
            let dayName: String
            if timeRange == .week {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "zh_CN")
                formatter.dateFormat = "EEE"
                dayName = formatter.string(from: date)
            } else if timeRange == .month {
                dayName = "\(calendar.component(.day, from: date))"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "M/d"
                dayName = formatter.string(from: date)
            }

            let count = completedTasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return calendar.isDate(completedAt, inSameDayAs: date)
            }.count

            data.append(.init(date: dayName, count: count))
        }
        return data
    }

    private var priorityData: [PriorityData] {
        [
            .init(priority: "低", count: taskStore.tasks.filter { $0.priority == .low }.count, color: .priorityLow),
            .init(priority: "中", count: taskStore.tasks.filter { $0.priority == .medium }.count, color: .priorityMedium),
            .init(priority: "高", count: taskStore.tasks.filter { $0.priority == .high }.count, color: .priorityHigh),
            .init(priority: "紧急", count: taskStore.tasks.filter { $0.priority == .urgent }.count, color: .priorityUrgent)
        ]
    }

    private var tagData: [TagData] {
        taskStore.tags.map { tag in
            let count = taskStore.tasks.filter { $0.tags.contains(tag.id) }.count
            return .init(tag: tag.name, count: count)
        }.sorted { $0.count > $1.count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: Time Range Picker
                    Picker("时间范围", selection: $timeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // MARK: Statistics Cards
                    statisticsCards

                    // MARK: Completion Trend Chart
                    if !completionData.isEmpty && completionData.contains(where: { $0.count > 0 }) {
                        chartSection(title: "任务完成趋势") {
                            Chart(completionData) { item in
                                BarMark(
                                    x: .value("日期", item.date),
                                    y: .value("数量", item.count)
                                )
                                .foregroundStyle(Color.themePrimary.gradient)
                            }
                            .frame(height: 200)
                        }
                    }

                    // MARK: Priority Distribution Chart
                    if priorityData.contains(where: { $0.count > 0 }) {
                        chartSection(title: "优先级分布") {
                            Chart(priorityData) { item in
                                SectorMark(
                                    angle: .value("数量", item.count),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 2
                                )
                                .foregroundStyle(item.color)
                            }
                            .frame(height: 200)
                        }
                    }

                    // MARK: Tag Distribution Chart
                    if !tagData.isEmpty {
                        chartSection(title: "标签分布") {
                            Chart(tagData) { item in
                                BarMark(
                                    x: .value("标签", item.tag),
                                    y: .value("数量", item.count)
                                )
                                .foregroundStyle(Color.themeSecondary.gradient)
                            }
                            .frame(height: 200)
                        }
                    }

                    // MARK: Empty State
                    if totalTasks == 0 {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("暂无任务数据")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("添加任务后，这里将显示统计信息")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 40)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("统计")
        }
    }

    // MARK: - Statistics Cards

    private var statisticsCards: some View {
        HStack(spacing: 12) {
            StatCard(title: "总任务", value: "\(totalTasks)", icon: "list.number", color: .blue)
            StatCard(title: "完成率", value: completionRate, icon: "checkmark.circle", color: .green)
            StatCard(title: "逾期", value: "\(overdueCount)", icon: "exclamationmark.triangle", color: .red)
        }
        .padding(.horizontal)
    }

    // MARK: - Chart Section

    private func chartSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)

            content()
                .padding(.horizontal)
        }
    }
}

// MARK: - StatCard

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title.bold())
                .foregroundStyle(.primary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Data Models

struct CompletionData: Identifiable {
    let id = UUID()
    let date: String
    let count: Int
}

struct PriorityData: Identifiable {
    let id = UUID()
    let priority: String
    let count: Int
    let color: Color
}

struct TagData: Identifiable {
    let id = UUID()
    let tag: String
    let count: Int
}

// MARK: - Preview

#Preview {
    StatisticsView()
        .environment(TaskStore.shared)
}
