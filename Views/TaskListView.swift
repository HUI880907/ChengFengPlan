// MARK: - TaskListView.swift
// 乘风计划 - 任务列表视图

import SwiftUI

// MARK: - TaskListView

struct TaskListView: View {
    @Environment(TaskStore.self) private var taskStore
    @State private var showingAddTask = false
    @State private var searchText = ""
    @State private var sortOption: SortOption = .dueDate

    var body: some View {
        NavigationStack {
            List {
                ForEach(taskStore.filteredAndSortedTasks()) { task in
                    TaskRowView(task: task)
                        .swipeActions(edge: .leading) {
                            Button {
                                withAnimation {
                                    taskStore.toggleTaskCompletion(id: task.id)
                                }
                            } label: {
                                Label(task.isCompleted ? "未完成" : "完成", systemImage: task.isCompleted ? "xmark" : "checkmark")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
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
            .listStyle(.plain)
            .navigationTitle("任务列表")
            .searchable(text: $searchText, prompt: "搜索任务")
            .onChange(of: searchText) { _, newValue in
                taskStore.searchText = newValue
            }
            .toolbar {
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
            .sheet(isPresented: $showingAddTask) {
                AddEditTaskView()
            }
        }
    }
}

// MARK: - TaskRowView

struct TaskRowView: View {
    @Bindable var task: TaskItem

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(priorityColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                if let dueDate = task.dueDate {
                    Text(formatDate(dueDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !task.description.isEmpty {
                    Text(task.description)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if task.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
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
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    TaskListView()
}
