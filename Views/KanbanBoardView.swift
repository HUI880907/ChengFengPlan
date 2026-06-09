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

// MARK: - CardDisplayOptions

struct CardDisplayOptions: Codable {
    var showDescription: Bool = true
    var showDueDate: Bool = true
    var showTags: Bool = true
    var showSubtasks: Bool = true
    var showPriority: Bool = true
    var showCreatedDate: Bool = false
}

// MARK: - KanbanBoardView

struct KanbanBoardView: View {
    @Environment(TaskStore.self) private var taskStore
    @AppStorage("kanban_card_options") private var cardOptionsData: Data = Data()
    @State private var showingCardSettings = false

    private var cardOptions: CardDisplayOptions {
        get {
            (try? JSONDecoder().decode(CardDisplayOptions.self, from: cardOptionsData)) ?? CardDisplayOptions()
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(KanbanColumn.allCases, id: \.self) { column in
                        KanbanColumnView(
                            column: column,
                            tasks: taskStore.tasks.filter { $0.status == column.taskStatus },
                            cardOptions: cardOptions,
                            onDrop: { task in
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
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("看板")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCardSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingCardSettings) {
                CardSettingsView(cardOptionsData: $cardOptionsData)
            }
        }
    }
}

// MARK: - KanbanColumnView

struct KanbanColumnView: View {
    let column: KanbanColumn
    let tasks: [TaskItem]
    let cardOptions: CardDisplayOptions
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
                    if tasks.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.title2)
                                .foregroundStyle(.secondary.opacity(0.5))
                            Text("暂无任务")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(tasks) { task in
                            KanbanCardView(task: task, options: cardOptions)
                                .draggable(task.id.uuidString) {
                                    KanbanCardView(task: task, options: cardOptions)
                                        .frame(width: 200)
                                }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .dropDestination(for: String.self) { items, _ in
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
    let options: CardDisplayOptions

    @Environment(TaskStore.self) private var taskStore

    private var taskTags: [TaskTag] {
        task.tags.compactMap { id in
            taskStore.tags.first { $0.id == id }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(task.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)

            // Description
            if options.showDescription && !task.description.isEmpty {
                Text(task.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Priority + Due Date
            HStack {
                if options.showPriority {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(task.priority.color)
                            .frame(width: 6, height: 6)
                        Text(task.priority.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if options.showDueDate, let dueDate = task.dueDate {
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: task.isOverdue ? "calendar.badge.exclamationmark" : "calendar")
                            .font(.caption2)
                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                        Text(DateFormatterCache.shared.format(dueDate, style: .date))
                            .font(.caption2)
                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                    }
                }
            }

            // Tags
            if options.showTags && !taskTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(taskTags) { tag in
                            Text(tag.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(tag.color.swiftUIColor.opacity(0.15))
                                .foregroundStyle(tag.color.swiftUIColor)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Subtasks indicator
            if options.showSubtasks && !task.subTaskIds.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "list.bullet.indent")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(task.subTaskIds.count) 个子任务")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - CardSettingsView

struct CardSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var cardOptionsData: Data

    private var cardOptions: CardDisplayOptions {
        get {
            (try? JSONDecoder().decode(CardDisplayOptions.self, from: cardOptionsData)) ?? CardDisplayOptions()
        }
    }

    private func saveOptions(_ options: CardDisplayOptions) {
        cardOptionsData = (try? JSONEncoder().encode(options)) ?? Data()
    }

    var body: some View {
        NavigationStack {
            List {
                Section("卡片显示内容") {
                    Toggle("显示描述", isOn: Binding(
                        get: { cardOptions.showDescription },
                        set: { var opts = cardOptions; opts.showDescription = $0; saveOptions(opts) }
                    ))
                    Toggle("显示截止日期", isOn: Binding(
                        get: { cardOptions.showDueDate },
                        set: { var opts = cardOptions; opts.showDueDate = $0; saveOptions(opts) }
                    ))
                    Toggle("显示优先级", isOn: Binding(
                        get: { cardOptions.showPriority },
                        set: { var opts = cardOptions; opts.showPriority = $0; saveOptions(opts) }
                    ))
                    Toggle("显示标签", isOn: Binding(
                        get: { cardOptions.showTags },
                        set: { var opts = cardOptions; opts.showTags = $0; saveOptions(opts) }
                    ))
                    Toggle("显示子任务", isOn: Binding(
                        get: { cardOptions.showSubtasks },
                        set: { var opts = cardOptions; opts.showSubtasks = $0; saveOptions(opts) }
                    ))
                    Toggle("显示创建日期", isOn: Binding(
                        get: { cardOptions.showCreatedDate },
                        set: { var opts = cardOptions; opts.showCreatedDate = $0; saveOptions(opts) }
                    ))
                }
            }
            .navigationTitle("卡片设置")
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
}

// MARK: - Preview

#Preview {
    KanbanBoardView()
        .environment(TaskStore.shared)
}
