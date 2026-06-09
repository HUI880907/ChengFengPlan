// MARK: - StatisticsView.swift
// 乘风计划 - 统计分析视图

import SwiftUI
import Charts

// MARK: - StatisticsView

struct StatisticsView: View {
    @State private var timeRange: TimeRange = .week

    enum TimeRange: String, CaseIterable {
        case week = "本周"
        case month = "本月"
        case year = "本年"
    }

    // 模拟数据
    private let completionData: [CompletionData] = [
        .init(date: "周一", count: 3),
        .init(date: "周二", count: 5),
        .init(date: "周三", count: 2),
        .init(date: "周四", count: 7),
        .init(date: "周五", count: 4),
        .init(date: "周六", count: 1),
        .init(date: "周日", count: 6)
    ]

    private let priorityData: [PriorityData] = [
        .init(priority: "低", count: 12, color: .priorityLow),
        .init(priority: "中", count: 18, color: .priorityMedium),
        .init(priority: "高", count: 8, color: .priorityHigh),
        .init(priority: "紧急", count: 3, color: .priorityUrgent)
    ]

    private let tagData: [TagData] = [
        .init(tag: "工作", count: 15),
        .init(tag: "学习", count: 10),
        .init(tag: "生活", count: 8),
        .init(tag: "健康", count: 5)
    ]

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
                    chartSection(title: "任务完成趋势") {
                        Chart(completionData) { item in
                            BarMark(
                                x: .value("日期", item.date),
                                y: .value("数量", item.count)
                            )
                            .foregroundStyle(Color.themePrimary.gradient)
                            .cornerRadius(4)
                        }
                        .frame(height: 200)
                    }

                    // MARK: Priority Distribution Chart
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

                    // MARK: Tag Distribution Chart
                    chartSection(title: "标签分布") {
                        Chart(tagData) { item in
                            BarMark(
                                x: .value("标签", item.tag),
                                y: .value("数量", item.count)
                            )
                            .foregroundStyle(Color.themeSecondary.gradient)
                            .cornerRadius(4)
                        }
                        .frame(height: 200)
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
            StatCard(title: "总任务", value: "41", icon: "list.number", color: .blue)
            StatCard(title: "完成率", value: "78%", icon: "checkmark.circle", color: .green)
            StatCard(title: "逾期", value: "2", icon: "exclamationmark.triangle", color: .red)
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
}
