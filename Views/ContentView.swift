// MARK: - ContentView.swift
// 乘风计划 - 主入口视图

import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    @Environment(TaskStore.self) private var taskStore
    @State private var selectedTab = 0
    @State private var showingBriefing = false
    @State private var showingAddTask = false
    @State private var showingSettings = false

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
        }
        .overlay(alignment: .topLeading) {
            topLeftButtons
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
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    // MARK: - Top Left Buttons (Settings + Daily Briefing)

    private var topLeftButtons: some View {
        HStack(spacing: 12) {
            // 设置按钮
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gear")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            // 每日简报按钮
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
        }
        .padding(.top, 8)
        .padding(.leading, 16)
    }

    // MARK: - Add Task FAB (Draggable)

    private var addButton: some View {
        DraggableAddButton {
            showingAddTask = true
        }
    }
}

// MARK: - DraggableAddButton

struct DraggableAddButton: View {
    let action: () -> Void

    @State private var position: CGPoint = CGPoint(x: UIScreen.main.bounds.width - 48, y: UIScreen.main.bounds.height - 140)
    @State private var isDragging = false
    @State private var isHidden = false
    @State private var dragOffset: CGSize = .zero

    private let buttonSize: CGFloat = 56
    private let edgeThreshold: CGFloat = 20
    private let hiddenRevealWidth: CGFloat = 24

    var body: some View {
        let currentX = position.x + dragOffset.width
        let currentY = position.y + dragOffset.height

        return Button(action: {
            if isHidden {
                withAnimation(.spring()) {
                    isHidden = false
                }
            } else {
                action()
            }
        }) {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: isHidden ? hiddenRevealWidth : buttonSize, height: buttonSize)
                .background(Color.themePrimary)
                .clipShape(Circle())
                .shadow(color: Color.themePrimary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .position(x: currentX, y: currentY)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    let newX = position.x + value.translation.width
                    let newY = position.y + value.translation.height

                    let screenWidth = UIScreen.main.bounds.width
                    let screenHeight = UIScreen.main.bounds.height

                    var finalX = max(buttonSize/2, min(screenWidth - buttonSize/2, newX))
                    var finalY = max(100, min(screenHeight - 100, newY))

                    // 贴边隐藏逻辑
                    let isNearLeftEdge = finalX < edgeThreshold + buttonSize/2
                    let isNearRightEdge = finalX > screenWidth - edgeThreshold - buttonSize/2

                    withAnimation(.spring()) {
                        if isNearRightEdge {
                            finalX = screenWidth - hiddenRevealWidth/2
                            isHidden = true
                        } else if isNearLeftEdge {
                            finalX = hiddenRevealWidth/2
                            isHidden = true
                        } else {
                            isHidden = false
                        }
                        position = CGPoint(x: finalX, y: finalY)
                        dragOffset = .zero
                    }
                }
        )
    }
}

// MARK: - DailyBriefingView

@MainActor
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
            ScrollView(.vertical) {
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
