// MARK: - TaskDetailView.swift
// 乘风计划 - 任务详情视图

import SwiftUI

// MARK: - TaskDetailView

struct TaskDetailView: View {
    @Bindable var task: TaskItem
    @State private var showingEditTask = false
    @State private var showingDeleteConfirmation = false
    @State private var showingAddLog = false
    @Environment(TaskStore.self) private var taskStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: Task Info
                taskInfoSection

                // MARK: Subtasks
                subtasksSection

                // MARK: Attachments
                attachmentsSection

                // MARK: Logs
                logsSection
            }
            .padding()
        }
        .navigationTitle("任务详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEditTask = true
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditTask) {
            AddEditTaskView(task: task)
        }
        .sheet(isPresented: $showingAddLog) {
            AddLogEntryView()
        }
        .alert("确认删除", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                taskStore.deleteTask(id: task.id)
                dismiss()
            }
        } message: {
            Text("确定要删除此任务吗？此操作不可撤销。")
        }
    }

    // MARK: - Task Info Section

    private var taskInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(task.priority.color)
                    .frame(width: 12, height: 12)

                Text(task.priority.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if task.isCompleted {
                    Label("已完成", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Text(task.title)
                .font(.title2.bold())

            if !task.description.isEmpty {
                Text(task.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if let dueDate = task.dueDate {
                HStack {
                    Image(systemName: "calendar")
                    Text("截止日期: \(DateFormatterCache.shared.format(dueDate, style: .medium))")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if !task.tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(task.tags, id: \.self) { tag in
                        Text(tag.uuidString.prefix(8))
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.themeSecondary.opacity(0.2))
                            .foregroundStyle(Color.themeSecondary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Subtasks Section

    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("子任务")
                    .font(.headline)

                Spacer()

                Text("\(task.subTaskIds.count) 个")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if task.subTaskIds.isEmpty {
                Text("暂无子任务")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                SubtaskListView(subTaskIds: task.subTaskIds)
            }
        }
    }

    // MARK: - Attachments Section

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("附件")
                .font(.headline)

            if task.attachments.isEmpty {
                Text("暂无附件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 12) {
                    ForEach(task.attachments) { attachment in
                        AttachmentPreview(name: attachment.filename, icon: "doc.fill", color: .blue)
                    }
                }
            }
        }
    }

    // MARK: - Logs Section

    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("日志记录")
                    .font(.headline)

                Spacer()

                Button {
                    showingAddLog = true
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color.themePrimary)
                }
            }

            if task.logEntries.isEmpty {
                Text("暂无日志")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(task.logEntries) { log in
                        LogEntryRow(log: log)
                    }
                }
            }
        }
    }
}

// MARK: - AttachmentPreview

struct AttachmentPreview: View {
    let name: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(name)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
        .frame(width: 80, height: 80)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - LogEntryRow

struct LogEntryRow: View {
    let log: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: log.type.displayName == "笔记" ? "note.text" : (log.type.displayName == "进度" ? "checkmark.circle" : (log.type.displayName == "问题" ? "exclamationmark.triangle" : "flag.fill")))
                .foregroundStyle(log.type.displayName == "进度" ? .green : (log.type.displayName == "问题" ? .orange : .blue))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(log.content)
                    .font(.body)

                Text(DateFormatterCache.shared.format(log.createdAt, style: .short))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - SubtaskListView

/// 独立的子任务列表视图，确保在 View body 上下文中访问 MainActor 隔离的 taskStore
struct SubtaskListView: View {
    let subTaskIds: [UUID]
    @Environment(TaskStore.self) private var taskStore

    var body: some View {
        VStack(spacing: 8) {
            ForEach(subTaskIds, id: \.self) { subTaskId in
                if let subTask = taskStore.tasks.first(where: { $0.id == subTaskId }) {
                    HStack {
                        Button {
                            withAnimation {
                                taskStore.toggleTaskCompletion(id: subTask.id)
                            }
                        } label: {
                            Image(systemName: subTask.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(subTask.isCompleted ? .green : .secondary)
                        }

                        Text(subTask.title)
                            .strikethrough(subTask.isCompleted)
                            .foregroundStyle(subTask.isCompleted ? .secondary : .primary)

                        Spacer()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TaskDetailView(task: TaskItem(title: "示例任务", priority: .high))
    }
}
