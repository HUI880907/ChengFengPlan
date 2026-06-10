// MARK: - TaskDetailView.swift
// 乘风计划 - 任务详情视图

import SwiftUI
import QuickLook

// MARK: - TaskDetailView

struct TaskDetailView: View {
    @Bindable var task: TaskItem
    @State private var showingEditTask = false
    @State private var showingDeleteConfirmation = false
    @State private var showingAddLog = false
    @State private var selectedAttachmentURL: URL?
    @State private var showingAttachmentPreview = false
    @Environment(TaskStore.self) private var taskStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: Task Info
                taskInfoSection

                // MARK: Statistics
                statisticsSection

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
            AddLogEntryView(task: task)
        }
        .sheet(isPresented: $showingAttachmentPreview) {
            if let url = selectedAttachmentURL {
                AttachmentPreviewSheet(url: url)
            }
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

                StatusBadge(status: task.status)
            }

            Text(task.title)
                .font(.title2.bold())

            if !task.description.isEmpty {
                Text(task.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
            }

            Divider()

            // 开始日期（创建日期）
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.plus")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text("开始日期")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(DateFormatterCache.shared.format(task.createdAt, style: .full))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

            if let dueDate = task.dueDate {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(task.isOverdue ? .red : .secondary)
                        .frame(width: 20)
                    Text("截止日期")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(DateFormatterCache.shared.format(dueDate, style: .full))
                        .font(.subheadline)
                        .foregroundStyle(task.isOverdue ? .red : .primary)
                    if task.isOverdue {
                        Text("已逾期")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
            }

            if !task.tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(task.tags, id: \.self) { tagId in
                        if let tag = taskStore.tags.first(where: { $0.id == tagId }) {
                            TagView(tag: tag)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("统计信息")
                    .font(.headline)

                Spacer()
            }

            VStack(spacing: 10) {
                StatRow(
                    icon: "calendar",
                    title: "创建时间",
                    value: DateFormatterCache.shared.format(task.createdAt, style: .full)
                )

                StatRow(
                    icon: "arrow.clockwise",
                    title: "最后更新",
                    value: DateFormatterCache.shared.format(task.updatedAt, style: .full)
                )

                if let completedAt = task.completedAt {
                    StatRow(
                        icon: "checkmark.circle.fill",
                        title: "完成时间",
                        value: DateFormatterCache.shared.format(completedAt, style: .full),
                        iconColor: .green
                    )
                }

                // 子任务完成进度
                if !task.subTaskIds.isEmpty {
                    let completedCount = completedSubtaskCount
                    let totalCount = task.subTaskIds.count
                    StatRow(
                        icon: "list.bullet",
                        title: "子任务进度",
                        value: "\(completedCount)/\(totalCount) 已完成",
                        iconColor: completedCount == totalCount ? .green : .blue
                    )
                }

                // 附件数量
                if !task.attachments.isEmpty {
                    StatRow(
                        icon: "paperclip",
                        title: "附件数量",
                        value: "\(task.attachments.count) 个",
                        iconColor: .orange
                    )
                }

                // 日志数量
                if !task.logEntries.isEmpty {
                    StatRow(
                        icon: "note.text",
                        title: "日志记录",
                        value: "\(task.logEntries.count) 条",
                        iconColor: .purple
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var completedSubtaskCount: Int {
        task.subTaskIds.compactMap { id in
            taskStore.tasks.first(where: { $0.id == id })
        }.filter(\.isCompleted).count
    }

    // MARK: - Subtasks Section

    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("子任务")
                    .font(.headline)

                Spacer()

                if !task.subTaskIds.isEmpty {
                    let completed = completedSubtaskCount
                    let total = task.subTaskIds.count
                    Text("\(completed)/\(total)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(completed == total ? Color.green : Color.themeSecondary)
                        .clipShape(Capsule())
                }
            }

            if task.subTaskIds.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.rectangle",
                    text: "暂无子任务"
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(task.subTaskIds, id: \.self) { subTaskId in
                        if let subTask = taskStore.tasks.first(where: { $0.id == subTaskId }) {
                            SubtaskRow(task: subTask)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Attachments Section

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("附件")
                    .font(.headline)

                Spacer()

                if !task.attachments.isEmpty {
                    Text("\(task.attachments.count) 个")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if task.attachments.isEmpty {
                EmptyStateView(
                    icon: "paperclip",
                    text: "暂无附件"
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90, maximum: 110))], spacing: 12) {
                    ForEach(task.attachments) { attachment in
                        AttachmentPreview(
                            attachment: attachment,
                            onTap: {
                                previewAttachment(attachment)
                            }
                        )
                    }
                }
            }
        }
    }

    private func previewAttachment(_ attachment: Attachment) {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(attachment.filename)
        do {
            try attachment.data.write(to: fileURL)
            selectedAttachmentURL = fileURL
            showingAttachmentPreview = true
        } catch {
            print("无法预览附件: \(error)")
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
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.themePrimary)
                        .font(.title3)
                }
            }

            if task.logEntries.isEmpty {
                EmptyStateView(
                    icon: "note.text",
                    text: "暂无日志"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(task.logEntries.sorted(by: { $0.createdAt > $1.createdAt })) { log in
                        LogEntryRow(log: log)
                    }
                }
            }
        }
    }
}

// MARK: - StatusBadge

struct StatusBadge: View {
    let status: TaskStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.caption2)
            Text(status.displayName)
                .font(.caption.bold())
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var statusIcon: String {
        switch status {
        case .pending: return "circle"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .pending: return .statusPending
        case .inProgress: return .statusInProgress
        case .completed: return .statusCompleted
        case .cancelled: return .gray
        }
    }
}

// MARK: - TagView

struct TagView: View {
    let tag: TaskTag

    var body: some View {
        Text(tag.name)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(tag.color.swiftUIColor.opacity(0.15))
            .foregroundStyle(tag.color.swiftUIColor)
            .clipShape(Capsule())
    }
}

// MARK: - StatRow

struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    var iconColor: Color = .secondary

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 20)
                .font(.subheadline)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - EmptyStateView

struct EmptyStateView: View {
    let icon: String
    let text: String

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.secondary.opacity(0.5))
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - SubtaskRow

struct SubtaskRow: View {
    @Bindable var task: TaskItem
    @Environment(TaskStore.self) private var taskStore

    var body: some View {
        HStack(spacing: 12) {
            // 更大的点击区域
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    taskStore.toggleTaskCompletion(id: task.id)
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                if let dueDate = task.dueDate {
                    Text("截止: \(DateFormatterCache.shared.format(dueDate, style: .medium))")
                        .font(.caption2)
                        .foregroundStyle(task.isOverdue ? .red : .secondary)
                }
            }

            Spacer()

            // 优先级小标记
            Circle()
                .fill(task.priority.color)
                .frame(width: 8, height: 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                taskStore.toggleTaskCompletion(id: task.id)
            }
        }
    }
}

// MARK: - AttachmentPreview

struct AttachmentPreview: View {
    let attachment: Attachment
    let onTap: () -> Void

    private var fileExtension: String {
        (attachment.filename as NSString).pathExtension.lowercased()
    }

    private var isImage: Bool {
        ["jpg", "jpeg", "png", "gif", "heic", "webp"].contains(fileExtension)
    }

    private var iconName: String {
        if isImage { return "photo.fill" }
        switch fileExtension {
        case "pdf": return "doc.text.fill"
        case "doc", "docx": return "doc.text.fill"
        case "xls", "xlsx": return "tablecells.fill"
        case "ppt", "pptx": return "play.rectangle.fill"
        case "txt", "md": return "text.alignleft"
        case "zip", "rar", "7z": return "archivebox.fill"
        default: return "doc.fill"
        }
    }

    private var iconColor: Color {
        if isImage { return .purple }
        switch fileExtension {
        case "pdf": return .red
        case "doc", "docx": return .blue
        case "xls", "xlsx": return .green
        case "ppt", "pptx": return .orange
        case "txt", "md": return .secondary
        case "zip", "rar", "7z": return .brown
        default: return .blue
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.12))
                        .frame(height: 70)

                    Image(systemName: iconName)
                        .font(.system(size: 28))
                        .foregroundStyle(iconColor)
                }

                Text(attachment.filename)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AttachmentPreviewSheet

struct AttachmentPreviewSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            QuickLookPreview(url: url)
                .navigationTitle(url.lastPathComponent)
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

// MARK: - QuickLookPreview (UIViewControllerRepresentable)

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}

// MARK: - LogEntryRow

struct LogEntryRow: View {
    let log: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 类型图标
            ZStack {
                Circle()
                    .fill(log.type.color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: log.type.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(log.type.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(log.type.displayName)
                        .font(.caption.bold())
                        .foregroundStyle(log.type.color)

                    Spacer()

                    Text(relativeTimeString(from: log.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(log.content)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Text(DateFormatterCache.shared.format(log.createdAt, style: .full))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func relativeTimeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
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

// MARK: - Preview

#Preview {
    NavigationStack {
        TaskDetailView(task: TaskItem(title: "示例任务", priority: .high))
    }
}
