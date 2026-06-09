// MARK: - KanbanBoardView.swift
// 乘风计划 - 看板视图

import SwiftUI

// MARK: - KanbanColumn

enum KanbanColumn: String, CaseIterable {
    case todo = "待办"
    case inProgress = "进行中"
    case done = "已完成"

    var color: Color {
        switch self {
        case .todo: return .statusPending
        case .inProgress: return .statusInProgress
        case .done: return .statusCompleted
        }
    }

    var taskStatus: TaskStatus {
        switch self {
        case .todo: return .pending
        case .inProgress: return .inProgress
        case .done: return .completed
        }
    }
}

// MARK: - KanbanBoardView

struct KanbanBoardView: View {
    @Environment(TaskStore.self) private var taskStore

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(KanbanColumn.allCases, id: \.self) { column in
                        KanbanColumnView(
                            column: column,
                            tasks: tasks(for: column),
                            onDrop: { task in
                                moveTask(task, to: column)
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("看板")
        }
    }

    private func tasks(for column: KanbanColumn) -> [TaskItem] {
        taskStore.tasks.filter { $0.status == column.taskStatus }
    }

    private func moveTask(_ task: TaskItem, to column: KanbanColumn) {
        withAnimation {
            var updatedTask = task
            switch column {
            case .todo:
                updatedTask.markAsPending()
            case .inProgress:
                updatedTask.markAsInProgress()
            case .done:
                updatedTask.markAsCompleted()
            }
            taskStore.updateTask(updatedTask)
        }
    }
}

// MARK: - KanbanColumnView

struct KanbanColumnView: View {
    let column: KanbanColumn
    let tasks: [TaskItem]
    let onDrop: (TaskItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: Column Header
            HStack {
                Text(column.rawValue)
                    .font(.headline)
                    .foregroundStyle(column.color)

                Spacer()

                Text("\(tasks.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(column.color)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            // MARK: Task Cards
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(tasks) { task in
                        KanbanCardView(task: task)
                            .draggable(task.id.uuidString) {
                                KanbanCardView(task: task)
                                    .frame(width: 200)
                            }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .dropDestination(for: String.self) { items, _ in
                // 简化演示：实际应通过 ID 查找任务
                return true
            }
        }
        .frame(width: 280)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - KanbanCardView

struct KanbanCardView: View {
    @Bindable var task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            HStack {
                Circle()
                    .fill(task.priority.color)
                    .frame(width: 8, height: 8)

                Text(task.priority.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview

#Preview {
    KanbanBoardView()
}
