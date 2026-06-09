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
            _dueDate = State(initialValue: task.dueDate ?? Date())
            _hasDueDate = State(initialValue: task.dueDate != nil)
            _tags = State(initialValue: task.tags)
        }
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
                                Text(p.rawValue)
                            }
                            .tag(p)
                        }
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
                        if let existingTask = task {
                            existingTask.title = title
                            existingTask.description = description
                            existingTask.priority = priority
                            existingTask.dueDate = hasDueDate ? dueDate : nil
                            existingTask.tags = tags
                            taskStore.updateTask(existingTask)
                        } else {
                            let newTask = TaskItem(
                                title: title,
                                description: description,
                                priority: priority,
                                dueDate: hasDueDate ? dueDate : nil,
                                tags: tags
                            )
                            taskStore.addTask(newTask)
                        }
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showingAIAssist) {
                AIAssistView(title: $title, description: $description)
            }
            .photosPicker(isPresented: $showingPhotosPicker, selection: $selectedPhotos, maxSelectionCount: 5, matching: .any(of: [.images, .videos]))
        }
    }

    // MARK: - Methods

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
