// MARK: - AddEditTaskView.swift
// 乘风计划 - 新建/编辑任务视图

import SwiftUI
import PhotosUI

// MARK: - AddEditTaskView

struct AddEditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TaskStore.self) private var taskStore
    var task: TaskItem?

    @State private var title = ""
    @State private var description = ""
    @State private var priority: TaskPriority = .medium
    @State private var startDate = Date()
    @State private var hasStartDate = false
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var tags: [UUID] = []
    @State private var tagNames: [String] = []
    @State private var newTag = ""
    @State private var repeatRule: RecurrenceRule = .none
    @State private var subtasks: [Subtask] = []
    @State private var newSubtask = ""
    @State private var showingAIAssist = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingPhotosPicker = false

    private var isEditing: Bool { task != nil }

    init(task: TaskItem? = nil) {
        self.task = task
        if let task = task {
            _title = State(initialValue: task.title)
            _priority = State(initialValue: task.priority)
            _startDate = State(initialValue: task.createdAt)
            _hasStartDate = State(initialValue: true)
            _dueDate = State(initialValue: task.dueDate ?? Date())
            _hasDueDate = State(initialValue: task.dueDate != nil)
            _tags = State(initialValue: task.tags)
        } else {
            _startDate = State(initialValue: Date())
            _hasStartDate = State(initialValue: true)
        }
    }

    /// 便利初始化器：从日历快速添加任务，预设截止日期
    init(initialDueDate: Date) {
        self.task = nil
        _title = State(initialValue: "")
        _priority = State(initialValue: .medium)
        _startDate = State(initialValue: Date())
        _hasStartDate = State(initialValue: true)
        _dueDate = State(initialValue: initialDueDate)
        _hasDueDate = State(initialValue: true)
        _tags = State(initialValue: [])
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: 基本信息
                Section("基本信息") {
                    TextField("任务标题", text: $title)

                    TextField("描述", text: $description, axis: .vertical)
                        .lineLimit(3...6)

                    Picker("优先级", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { p in
                            HStack {
                                Circle()
                                    .fill(p.color)
                                    .frame(width: 8, height: 8)
                                Text(p.displayName)
                            }
                            .tag(p)
                        }
                    }
                }

                // MARK: 开始日期
                Section("开始日期") {
                    Toggle("设置开始日期", isOn: $hasStartDate)
                    if hasStartDate {
                        DatePicker("", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical)
                    }
                }

                // MARK: 截止日期
                Section("截止日期") {
                    Toggle("设置截止日期", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical)
                    }
                }

                // MARK: 重复规则
                Section("重复") {
                    Picker("重复规则", selection: $repeatRule) {
                        ForEach(RecurrenceRule.allCases, id: \.self) { rule in
                            Text(rule.displayName).tag(rule)
                        }
                    }
                }

                // MARK: 标签
                Section("标签") {
                    HStack {
                        TextField("添加标签", text: $newTag)
                        Button {
                            let trimmed = newTag.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty, !tagNames.contains(trimmed) else { return }
                            tagNames.append(trimmed)
                            if let existingTag = taskStore.tags.first(where: { $0.name == trimmed }) {
                                tags.append(existingTag.id)
                            } else {
                                let newTagItem = TaskTag(name: trimmed, color: .blue)
                                taskStore.addTag(newTagItem)
                                tags.append(newTagItem.id)
                            }
                            newTag = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newTag.isEmpty)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tagNames, id: \.self) { tagName in
                                HStack(spacing: 4) {
                                    Text(tagName)
                                        .font(.caption)
                                    Button {
                                    tagNames.removeAll { $0 == tagName }
                                    if let existingTag = taskStore.tags.first(where: { $0.name == tagName }) {
                                        tags.removeAll { $0 == existingTag.id }
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption2)
                                }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.themeSecondary.opacity(0.2))
                                .foregroundStyle(Color.themeSecondary)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }

                // MARK: 子任务
                Section("子任务") {
                    HStack {
                        TextField("添加子任务", text: $newSubtask)
                        Button {
                            addSubtask()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newSubtask.isEmpty)
                    }

                    ForEach(subtasks) { subtask in
                        HStack {
                            Text(subtask.title)
                            Spacer()
                            Button {
                                removeSubtask(subtask)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }

                // MARK: 附件
                Section("附件") {
                    Button {
                        showingPhotosPicker = true
                    } label: {
                        Label("添加附件", systemImage: "paperclip")
                    }

                    if !selectedPhotos.isEmpty {
                        Text("已选择 \(selectedPhotos.count) 个附件")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: AI 辅助
                Section {
                    Button {
                        showingAIAssist = true
                    } label: {
                        Label("AI 辅助输入", systemImage: "sparkles")
                            .foregroundStyle(Color.themePrimary)
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑任务" : "新建任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveTask()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                loadExistingSubtasks()
            }
            .sheet(isPresented: $showingAIAssist) {
                AIAssistView(title: $title, description: $description)
            }
            .photosPicker(isPresented: $showingPhotosPicker, selection: $selectedPhotos, maxSelectionCount: 5, matching: .any(of: [.images, .videos]))
        }
    }

    // MARK: - Methods

    private func saveTask() {
        if let existingTask = task {
            // 编辑已有任务
            existingTask.title = title
            existingTask.description = description
            existingTask.priority = priority
            existingTask.dueDate = hasDueDate ? dueDate : nil
            existingTask.tags = tags
            taskStore.updateTask(existingTask)

            // 同步子任务：移除已删除的，添加新增的
            syncSubtasks(for: existingTask)

            // 处理新选择的附件
            processAttachments(for: existingTask)
        } else {
            // 创建新任务
            let newTask = TaskItem(
                title: title,
                description: description,
                priority: priority,
                createdAt: hasStartDate ? startDate : Date(),
                dueDate: hasDueDate ? dueDate : nil,
                tags: tags
            )
            taskStore.addTask(newTask)

            // 为新任务创建子任务
            for subtask in subtasks {
                let childTask = TaskItem(
                    title: subtask.title,
                    parentTaskId: newTask.id
                )
                if subtask.isCompleted {
                    childTask.markAsCompleted()
                }
                taskStore.addTask(childTask)
                newTask.addSubTask(childTask.id)
            }

            // 处理附件
            processAttachments(for: newTask)
        }
        dismiss()
    }

    /// 同步子任务（编辑模式）：对比现有子任务和当前 subtasks 数组
    private func syncSubtasks(for parentTask: TaskItem) {
        // 获取当前已存在的子任务
        let existingChildTasks = taskStore.tasks.filter { $0.parentTaskId == parentTask.id }
        let existingChildIds = Set(existingChildTasks.map { $0.id })

        // 当前 UI 中的子任务 ID 集合（用于判断哪些是已有的）
        let currentSubtaskIds = Set(parentTask.subTaskIds)

        // 1. 删除已被用户移除的子任务
        for childTask in existingChildTasks {
            if !subtasks.contains(where: { $0.id == childTask.id }) {
                // 该子任务在 UI 中已被移除，删除它
                taskStore.deleteTask(id: childTask.id)
                parentTask.removeSubTask(childTask.id)
            }
        }

        // 2. 添加新增的子任务
        for subtask in subtasks {
            if !currentSubtaskIds.contains(subtask.id) && !existingChildIds.contains(subtask.id) {
                // 这是新增的子任务
                let childTask = TaskItem(
                    title: subtask.title,
                    parentTaskId: parentTask.id
                )
                if subtask.isCompleted {
                    childTask.markAsCompleted()
                }
                taskStore.addTask(childTask)
                parentTask.addSubTask(childTask.id)
            } else if let existingChild = existingChildTasks.first(where: { $0.id == subtask.id }) {
                // 更新已有子任务的标题和完成状态
                existingChild.title = subtask.title
                if subtask.isCompleted && !existingChild.isCompleted {
                    existingChild.markAsCompleted()
                } else if !subtask.isCompleted && existingChild.isCompleted {
                    existingChild.markAsPending()
                }
                taskStore.updateTask(existingChild)
            }
        }
    }

    /// 加载已有子任务（编辑模式）
    private func loadExistingSubtasks() {
        guard let task = task else { return }
        let childTasks = taskStore.tasks.filter { $0.parentTaskId == task.id }
        subtasks = childTasks.map { Subtask(id: $0.id, title: $0.title, isCompleted: $0.isCompleted) }
    }

    /// 将用户选择的图片转换为 Attachment 并添加到任务
    private func processAttachments(for targetTask: TaskItem) {
        guard !selectedPhotos.isEmpty else { return }

        for (index, photoItem) in selectedPhotos.enumerated() {
            photoItem.loadTransferable(type: Data.self) { result in
                DispatchQueue.main.async {
                    if let data = try? result.get(), !data.isEmpty {
                        let filename = "attachment_\(index + 1).jpg"
                        let attachment = Attachment(filename: filename, data: data)
                        targetTask.addAttachment(attachment)
                    }
                }
            }
        }
    }

    private func addSubtask() {
        let trimmed = newSubtask.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        subtasks.append(Subtask(title: trimmed))
        newSubtask = ""
    }

    private func removeSubtask(_ subtask: Subtask) {
        subtasks.removeAll { $0.id == subtask.id }
    }
}

// MARK: - AIAssistView

struct AIAssistView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var title: String
    @Binding var description: String
    @State private var prompt = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("描述您想要创建的任务，AI 将帮您生成标题和描述")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("例如：下周三之前完成项目报告", text: $prompt, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)

                if isLoading {
                    ProgressView("AI 生成中...")
                }

                Spacer()
            }
            .padding()
            .navigationTitle("AI 辅助")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("生成") {
                        generateWithAI()
                    }
                    .disabled(prompt.isEmpty || isLoading)
                }
            }
        }
    }

    private func generateWithAI() {
        isLoading = true
        // 模拟 AI 生成
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            title = "完成项目报告"
            description = "根据 AI 分析，您需要：\n1. 收集数据\n2. 撰写报告\n3. 审阅并提交"
            isLoading = false
            dismiss()
        }
    }
}

// MARK: - Subtask

struct Subtask: Identifiable {
    let id: UUID
    var title: String
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

// MARK: - Preview

#Preview {
    AddEditTaskView()
}
