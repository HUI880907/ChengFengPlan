// MARK: - ContentView.swift
// 乘风计划 - 主入口视图

import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    @Environment(TaskStore.self) private var taskStore
    @State private var selectedTab = 0
    @State private var showingBriefing = false
    @State private var showingAddTask = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: 任务列表
            TaskListView()
                .tabItem {
                    Label("任务", systemImage: "list.bullet")
                }
                .tag(0)

            // MARK: 看板
            KanbanBoardView()
                .tabItem {
                    Label("看板", systemImage: "square.grid.2x2")
                }
                .tag(1)

            // MARK: 日历
            CalendarView()
                .tabItem {
                    Label("日历", systemImage: "calendar")
                }
                .tag(2)

            // MARK: 统计
            StatisticsView()
                .tabItem {
                    Label("统计", systemImage: "chart.bar")
                }
                .tag(3)

            // MARK: 助手
            AIAssistantView()
                .tabItem {
                    Label("助手", systemImage: "sparkles")
                }
                .tag(4)

            // MARK: 设置
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(5)
        }
        .overlay(alignment: .topTrailing) {
            dailyBriefingButton
        }
        .overlay(alignment: .bottomTrailing) {
            addButton
        }
        .sheet(isPresented: $showingBriefing) {
            DailyBriefingView()
        }
        .sheet(isPresented: $showingAddTask) {
            AddEditTaskView()
        }
    }

    // MARK: - Daily Briefing Button

    private var dailyBriefingButton: some View {
        Button {
            showingBriefing = true
        } label: {
            Image(systemName: "sunrise.fill")
                .font(.title3)
                .foregroundStyle(.orange)
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .padding(.top, 8)
        .padding(.trailing, 16)
    }

    // MARK: - Add Task FAB

    private var addButton: some View {
        Button {
            showingAddTask = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.themePrimary)
                .clipShape(Circle())
                .shadow(color: Color.themePrimary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 80)
    }
}

// MARK: - DailyBriefingView

struct DailyBriefingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TaskStore.self) private var taskStore

    private var todayTasks: [TaskItem] {
        let today = Date()
        return taskStore.tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: today) && task.status != .completed && task.status != .cancelled
        }
    }

    private var overdueTasks: [TaskItem] {
        taskStore.getOverdueTasks()
    }

    private var highPriorityTasks: [TaskItem] {
        todayTasks.filter { $0.priority == .high || $0.priority == .urgent }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("今日简报")
                        .font(.largeTitle.bold())

                    briefingSection(title: "待办任务", icon: "checklist", color: .blue) {
                        if todayTasks.isEmpty {
                            Text("暂无待办任务")
                        } else {
                            Text("您今天有 \(todayTasks.count) 项待办任务")
                            ForEach(todayTasks.prefix(5)) { task in
                                HStack {
                                    Circle().fill(task.priority.color).frame(width: 8, height: 8)
                                    Text(task.title).font(.subheadline)
                                    Spacer()
                                }
                            }
                            if todayTasks.count > 5 {
                                Text("还有 \(todayTasks.count - 5) 项...")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }

                    briefingSection(title: "逾期提醒", icon: "exclamationmark.triangle", color: .red) {
                        if overdueTasks.isEmpty {
                            Text("没有逾期任务")
                        } else {
                            Text("有 \(overdueTasks.count) 项任务已逾期")
                            ForEach(overdueTasks.prefix(3)) { task in
                                HStack {
                                    Circle().fill(.red).frame(width: 8, height: 8)
                                    Text(task.title).font(.subheadline)
                                    Spacer()
                                }
                            }
                        }
                    }

                    briefingSection(title: "今日专注", icon: "brain.head.profile", color: .purple) {
                        if highPriorityTasks.isEmpty {
                            Text("今天没有高优先级任务，合理安排时间即可")
                        } else {
                            Text("建议优先处理 \(highPriorityTasks.count) 项高优先级任务")
                            ForEach(highPriorityTasks.prefix(3)) { task in
                                HStack {
                                    Circle().fill(task.priority.color).frame(width: 8, height: 8)
                                    Text(task.title).font(.subheadline)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("每日简报")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func briefingSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
            content()
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(TaskStore.shared)
}
