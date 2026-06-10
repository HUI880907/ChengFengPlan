// MARK: - TaskListView.swift
// 乘风计划 - 任务列表视图

import SwiftUI

// MARK: - TaskListView

struct TaskListView: View {
    @Environment(TaskStore.self) private var taskStore
    @State private var showingAddTask = false
    @State private var searchText = ""
    @State private var sortOption: SortOption = .dueDate

    // MARK: - Multi-Select State
    @State private var isMultiSelectMode = false
    @State private var selectedTaskIds = Set<UUID>()
    @State private var showingPriorityPicker = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    ForEach(taskStore.filteredAndSortedTasks()) { task in
                        TaskRowView(
                            task: task,
                            isMultiSelectMode: isMultiSelectMode,
                            isSelected: selectedTaskIds.contains(task.id)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isMultiSelectMode {
                                toggleSelection(for: task.id)
                            }
                        }
                        .onLongPressGesture {
                            if !isMultiSelectMode {
                                enterMultiSelectMode(initialTaskId: task.id)
                            }
                        }
                        .background(
                            NavigationLink(value: task) {
                                EmptyView()
                            }
                            .opacity(0)
                            .disabled(isMultiSelectMode)
                        )
                        .swipeActions(edge: .leading) {
                            if !isMultiSelectMode {
                                Button {
                                    withAnimation {
                                        taskStore.toggleTaskCompletion(id: task.id)
                                    }
                                } label: {
                                    Label(task.isCompleted ? "未完成" : "完成", systemImage: task.isCompleted ? "xmark" : "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            if !isMultiSelectMode {
                                Button(role: .destructive) {
                                    withAnimation {
                                        taskStore.deleteTask(id: task.id)
                                    }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .navigationTitle("任务列表")
                .searchable(text: $searchText, prompt: "搜索任务")
                .onChange(of: searchText) { _, newValue in
                    taskStore.searchText = newValue
                }
                .toolbar {
                    if isMultiSelectMode {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                cancelMultiSelect()
                            } label: {
                                Text("取消")
                            }
                        }
                        ToolbarItem(placement: .principal) {
                            Text("已选择 \(selectedTaskIds.count) 项")
                                .font(.headline)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                if selectedTaskIds.count == taskStore.filteredAndSortedTasks().count {
                                    selectedTaskIds.removeAll()
                                } else {
                                    selectedTaskIds = Set(taskStore.filteredAndSortedTasks().map { $0.id })
                                }
                            } label: {
                                Text(selectedTaskIds.count == taskStore.filteredAndSortedTasks().count ? "取消全选" : "全选")
                            }
                        }
                    } else {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Picker("排序", selection: $sortOption) {
                                    ForEach(SortOption.allCases, id: \.self) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                                .onChange(of: sortOption) { _, newValue in
                                    taskStore.sortOption = newValue
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingAddTask = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingAddTask) {
                    AddEditTaskView()
                }
                .navigationDestination(for: TaskItem.self) { task in
                    TaskDetailView(task: task)
                }

                // MARK: - Bottom Batch Actions Toolbar
                if isMultiSelectMode {
                    batchActionsToolbar
                        .transition(.move(edge: .bottom))
                }
            }
            .sheet(isPresented: $showingPriorityPicker) {
                PriorityPickerSheet { priority in
                    batchChangePriority(to: priority)
                }
            }
        }
    }

    // MARK: - Multi-Select Logic

    private func enterMultiSelectMode(initialTaskId: UUID) {
        withAnimation {
            isMultiSelectMode = true
            selectedTaskIds.insert(initialTaskId)
        }
    }

    private func cancelMultiSelect() {
        withAnimation {
            isMultiSelectMode = false
            selectedTaskIds.removeAll()
        }
    }

    private func toggleSelection(for id: UUID) {
        if selectedTaskIds.contains(id) {
            selectedTaskIds.remove(id)
            if selectedTaskIds.isEmpty {
                withAnimation {
                    isMultiSelectMode = false
                }
            }
        } else {
            selectedTaskIds.insert(id)
        }
    }

    // MARK: - Batch Actions

    @MainActor
    private func batchMarkCompleted() {
        for id in selectedTaskIds {
            taskStore.toggleTaskCompletion(id: id)
        }
        cancelMultiSelect()
    }

    @MainActor
    private func batchDelete() {
        for id in selectedTaskIds {
            taskStore.deleteTask(id: id)
        }
        cancelMultiSelect()
    }

    @MainActor
    private func batchChangePriority(to priority: TaskPriority) {
        for id in selectedTaskIds {
            if let index = taskStore.tasks.firstIndex(where: { $0.id == id }) {
                taskStore.tasks[index].priority = priority
                taskStore.tasks[index].updatedAt = Date()
            }
        }
        Task { @MainActor in
            await taskStore.saveTasks()
        }
        cancelMultiSelect()
    }

    // MARK: - Bottom Toolbar View

    private var batchActionsToolbar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                BatchActionButton(
                    icon: "checkmark.circle.fill",
                    title: "完成",
                    color: .green
                ) {
                    Task { @MainActor in
                        batchMarkCompleted()
                    }
                }

                BatchActionButton(
                    icon: "trash.fill",
                    title: "删除",
                    color: .red
                ) {
                    Task { @MainActor in
                        batchDelete()
                    }
                }

                BatchActionButton(
                    icon: "flag.fill",
                    title: "优先级",
                    color: .orange
                ) {
                    showingPriorityPicker = true
                }

                BatchActionButton(
                    icon: "xmark.circle.fill",
                    title: "取消",
                    color: .gray
                ) {
                    cancelMultiSelect()
                }
            }
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Batch Action Button

struct BatchActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Priority Picker Sheet

struct PriorityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (TaskPriority) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    Button {
                        onSelect(priority)
                        dismiss()
                    } label: {
                        HStack {
                            Circle()
                                .fill(priority.color)
                                .frame(width: 10, height: 10)
                            Text(priority.displayName)
                            Spacer()
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("选择优先级")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - TaskPriority Color Extension



// MARK: - TaskRowView

struct TaskRowView: View {
    @Bindable var task: TaskItem
    let isMultiSelectMode: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Multi-select checkbox
            if isMultiSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.title3)
            }

            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 10, height: 10)

            // Task info - 3 rows
            VStack(alignment: .leading, spacing: 4) {
                // Row 1: Task title (bold)
                Text(task.title)
                    .font(.body.bold())
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(1)

                // Row 2: Task description (gray, max 2 lines)
                if !task.description.isEmpty {
                    Text(task.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Row 3: Start date - End date | Priority
                HStack(spacing: 4) {
                    Text("\(formatDate(task.createdAt)) - \(task.dueDate != nil ? formatDate(task.dueDate!) : "无截止日期")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("|")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(task.priority.displayName)
                        .font(.caption)
                        .foregroundStyle(priorityColor)
                }
            }

            Spacer()

            // Completed indicator
            if task.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 6)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: return .priorityLow
        case .medium: return .priorityMedium
        case .high: return .priorityHigh
        case .urgent: return .priorityUrgent
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    TaskListView()
}
