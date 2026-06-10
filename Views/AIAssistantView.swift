// MARK: - AIAssistantView.swift
// 乘风计划 - AI 助手聊天视图

import SwiftUI

// MARK: - ParsedTaskInfo

/// 从自然语言中解析出的任务信息
struct ParsedTaskInfo: Identifiable {
    let id = UUID()
    var title: String
    var dueDate: Date?
    var location: String?
    var description: String
    var priority: TaskPriority = .medium
}

// MARK: - UserIntent

/// 识别到的用户意图
enum UserIntent {
    case createTask(ParsedTaskInfo)
    case deleteTask(TaskItem)
    case completeTask(TaskItem)
    case updateTask(TaskItem)
    case query(String)
    case unknown
}

// MARK: - AIAssistantView

@MainActor
struct AIAssistantView: View {
    @Environment(TaskStore.self) private var taskStore
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, content: "您好！我是乘风计划的 AI 助手。我可以帮您分析任务、提供建议、总结今天的工作，甚至直接帮您创建、删除或完成任务。请问有什么可以帮您的吗？")
    ]
    @State private var inputText = ""
    @State private var isLoading = false
    @FocusState private var isInputFocused: Bool

    // MARK: - Dialog States
    @State private var showCreateConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showCompleteConfirm = false
    @State private var showEditSheet = false
    @State private var pendingParsedTask: ParsedTaskInfo?
    @State private var pendingTaskItem: TaskItem?
    @State private var pendingTaskForEdit: TaskItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color(.systemGray5))
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // MARK: Quick Actions
                quickActions

                // MARK: Input Bar
                inputBar
            }
            .navigationTitle("AI 助手")
        }
        // MARK: - Confirmation Dialogs
        .confirmationDialog(
            "确认创建任务",
            isPresented: $showCreateConfirm,
            titleVisibility: .visible
        ) {
            Button("确认创建", role: .none) {
                if let info = pendingParsedTask {
                    createTaskFromParsed(info)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let info = pendingParsedTask {
                Text("标题：\(info.title)\n" +
                     (info.dueDate != nil ? "时间：\(formatDate(info.dueDate!))\n" : "") +
                     (info.location != nil ? "地点：\(info.location!)\n" : "") +
                     "\n是否确认创建此任务？")
            }
        }
        .alert(
            "确认删除任务",
            isPresented: $showDeleteConfirm
        ) {
            Button("删除", role: .destructive) {
                if let task = pendingTaskItem {
                    taskStore.deleteTask(id: task.id)
                    let msg = ChatMessage(role: .assistant, content: "✅ 已删除任务「\(task.title)」")
                    messages.append(msg)
                    AIManager.shared.chatHistory.append(msg)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let task = pendingTaskItem {
                Text("确定要删除任务「\(task.title)」吗？此操作不可撤销。")
            }
        }
        .alert(
            "确认完成任务",
            isPresented: $showCompleteConfirm
        ) {
            Button("标记完成", role: .none) {
                if let task = pendingTaskItem {
                    taskStore.toggleTaskCompletion(id: task.id)
                    let msg = ChatMessage(role: .assistant, content: "✅ 已将任务「\(task.title)」标记为已完成，恭喜！")
                    messages.append(msg)
                    AIManager.shared.chatHistory.append(msg)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let task = pendingTaskItem {
                Text("确定要将「\(task.title)」标记为已完成吗？")
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let task = pendingTaskForEdit {
                TaskEditSheet(task: task, onSave: { updatedTask in
                    taskStore.updateTask(updatedTask)
                    let msg = ChatMessage(role: .assistant, content: "✅ 已更新任务「\(updatedTask.title)」")
                    messages.append(msg)
                    AIManager.shared.chatHistory.append(msg)
                })
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                QuickActionButton(title: "分析任务", icon: "chart.bar") {
                    sendQuickMessage("请分析我的任务")
                }
                QuickActionButton(title: "建议任务", icon: "lightbulb") {
                    sendQuickMessage("请给我一些任务建议")
                }
                QuickActionButton(title: "总结今天", icon: "calendar.badge.clock") {
                    sendQuickMessage("请总结我今天的工作")
                }
                QuickActionButton(title: "优化计划", icon: "arrow.triangle.2.circlepath") {
                    sendQuickMessage("请帮我优化任务计划")
                }
                QuickActionButton(title: "时间管理", icon: "clock") {
                    sendQuickMessage("请给我一些时间管理建议")
                }
                QuickActionButton(title: "周报生成", icon: "doc.text") {
                    sendQuickMessage("请帮我生成本周工作周报")
                }
                QuickActionButton(title: "逾期分析", icon: "exclamationmark.triangle") {
                    sendQuickMessage("请分析我的逾期任务")
                }
                QuickActionButton(title: "专注建议", icon: "brain.head.profile") {
                    sendQuickMessage("请给我提高专注力的建议")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("输入消息...", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .focused($isInputFocused)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(inputText.isEmpty ? .secondary : Color.themePrimary)
            }
            .disabled(inputText.isEmpty || isLoading)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Methods

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        AIManager.shared.chatHistory.append(userMessage)
        inputText = ""
        isLoading = true

        // 先尝试识别用户意图（创建/删除/完成任务）
        if let intent = detectIntent(from: text) {
            isLoading = false
            handleIntent(intent, originalText: text)
            return
        }

        // 尝试调用真实AI，如果没有配置API Key则使用本地分析
        Task {
            let response = await AIManager.shared.chat(prompt: text)
            await MainActor.run {
                if response.isSuccess && !response.content.isEmpty {
                    let assistantContent = response.content
                    // 检查 AI 响应是否包含创建任务的关键词
                    if let parsedTask = parseTaskFromAIResponse(assistantContent, originalInput: text) {
                        isLoading = false
                        pendingParsedTask = parsedTask
                        showCreateConfirm = true
                        let msg = ChatMessage(role: .assistant, content: assistantContent)
                        messages.append(msg)
                        AIManager.shared.chatHistory.append(msg)
                    } else {
                        let msg = ChatMessage(role: .assistant, content: assistantContent)
                        messages.append(msg)
                        AIManager.shared.chatHistory.append(msg)
                    }
                } else {
                    // Fallback到本地分析
                    let localResponse = generateLocalResponse(to: text)
                    let msg = ChatMessage(role: .assistant, content: localResponse)
                    messages.append(msg)
                    AIManager.shared.chatHistory.append(msg)
                }
                isLoading = false
            }
        }
    }

    private func sendQuickMessage(_ text: String) {
        inputText = text
        sendMessage()
    }

    // MARK: - Intent Detection & Handling

    /// 检测用户意图（创建/删除/完成/修改任务）
    private func detectIntent(from text: String) -> UserIntent? {
        let lowerText = text.lowercased()

        // 1. 删除任务意图
        if lowerText.contains("删除") {
            if let task = findTaskByKeyword(in: text) {
                return .deleteTask(task)
            }
        }

        // 2. 完成任务意图
        if lowerText.contains("完成") || lowerText.contains("做完") || lowerText.contains("标记完成") {
            if let task = findTaskByKeyword(in: text) {
                return .completeTask(task)
            }
        }

        // 3. 修改任务意图
        if lowerText.contains("修改") || lowerText.contains("编辑") || lowerText.contains("更改") {
            if let task = findTaskByKeyword(in: text) {
                return .updateTask(task)
            }
        }

        // 4. 创建任务意图（包含时间/地点信息）
        let createKeywords = ["创建任务", "添加任务", "新建任务", "设置任务", "安排", "提醒"]
        let hasCreateKeyword = createKeywords.contains { lowerText.contains($0) }
        let hasTimeOrLocation = containsTimeOrLocationInfo(text)

        if hasCreateKeyword || hasTimeOrLocation {
            if let parsedTask = parseNaturalLanguageTask(text) {
                return .createTask(parsedTask)
            }
        }

        return nil
    }

    /// 处理识别到的意图
    private func handleIntent(_ intent: UserIntent, originalText: String) {
        switch intent {
        case .createTask(let info):
            pendingParsedTask = info
            showCreateConfirm = true
            let msg = ChatMessage(role: .assistant, content: "我为您解析到以下任务信息：\n\n标题：\(info.title)\n" +
                (info.dueDate != nil ? "时间：\(formatDate(info.dueDate!))\n" : "") +
                (info.location != nil ? "地点：\(info.location!)\n" : "") +
                "\n请确认是否创建此任务？")
            messages.append(msg)
            AIManager.shared.chatHistory.append(msg)

        case .deleteTask(let task):
            pendingTaskItem = task
            showDeleteConfirm = true
            let msg = ChatMessage(role: .assistant, content: "找到任务「\(task.title)」，请确认是否删除？")
            messages.append(msg)
            AIManager.shared.chatHistory.append(msg)

        case .completeTask(let task):
            pendingTaskItem = task
            showCompleteConfirm = true
            let msg = ChatMessage(role: .assistant, content: "找到任务「\(task.title)」，请确认是否标记为已完成？")
            messages.append(msg)
            AIManager.shared.chatHistory.append(msg)

        case .updateTask(let task):
            pendingTaskForEdit = task
            showEditSheet = true
            let msg = ChatMessage(role: .assistant, content: "已打开任务「\(task.title)」的编辑界面，请修改后保存。")
            messages.append(msg)
            AIManager.shared.chatHistory.append(msg)

        case .query, .unknown:
            break
        }
    }

    /// 根据关键词查找任务
    private func findTaskByKeyword(in text: String) -> TaskItem? {
        // 提取引号内的内容或"xxx任务"中的xxx
        let patterns = [
            "「([^」]+)」",
            "\\\"([^\"]+)\\\"",
            "'([^']+)'",
            "《([^》]+)》",
            "删除(.+?)任务",
            "完成(.+?)任务",
            "修改(.+?)任务",
            "编辑(.+?)任务"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
                if let range = Range(match.range(at: 1), in: text) {
                    let keyword = String(text[range]).trimmingCharacters(in: .whitespaces)
                    if let task = taskStore.searchTasks(query: keyword).first {
                        return task
                    }
                }
            }
        }

        // 如果没有匹配到引号内容，尝试用整句话搜索（去掉常见动词）
        let cleaned = text
            .replacingOccurrences(of: "删除", with: "")
            .replacingOccurrences(of: "完成", with: "")
            .replacingOccurrences(of: "修改", with: "")
            .replacingOccurrences(of: "编辑", with: "")
            .replacingOccurrences(of: "任务", with: "")
            .trimmingCharacters(in: .whitespaces)

        if !cleaned.isEmpty {
            return taskStore.searchTasks(query: cleaned).first
        }

        return nil
    }

    /// 检查文本是否包含时间或地点信息
    private func containsTimeOrLocationInfo(_ text: String) -> Bool {
        let timePatterns = ["明天", "后天", "今天", "下午", "上午", "晚上", "早上", "点", "分", "号", "日", "周", "星期", "月"]
        let locationPatterns = ["在", "去", "到", "会议室", "办公室", "家里", "学校", "公司"]
        return timePatterns.contains { text.contains($0) } || locationPatterns.contains { text.contains($0) }
    }

    /// 从自然语言解析任务信息
    private func parseNaturalLanguageTask(_ text: String) -> ParsedTaskInfo? {
        var title = text
        var dueDate: Date?
        var location: String?
        var description = ""

        let calendar = Calendar.current
        let now = Date()

        // 解析日期
        if text.contains("明天") {
            dueDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            title = title.replacingOccurrences(of: "明天", with: "")
        } else if text.contains("后天") {
            dueDate = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now))
            title = title.replacingOccurrences(of: "后天", with: "")
        } else if text.contains("今天") {
            dueDate = calendar.startOfDay(for: now)
            title = title.replacingOccurrences(of: "今天", with: "")
        }

        // 解析时间（下午1点、上午9点、晚上8点等）
        let timePatterns: [(pattern: String, hourOffset: Int)] = [
            ("下午([0-9]+)点", 12),
            ("晚上([0-9]+)点", 12),
            ("上午([0-9]+)点", 0),
            ("早上([0-9]+)点", 0),
            ("凌晨([0-9]+)点", 0),
            ("([0-9]+)点", 0)
        ]

        for (pattern, hourOffset) in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
               let range = Range(match.range(at: 1), in: text),
               let hour = Int(text[range]) {
                var adjustedHour = hour
                if hourOffset == 12 && hour < 12 {
                    adjustedHour = hour + 12
                }
                let baseDate = dueDate ?? calendar.startOfDay(for: now)
                dueDate = calendar.date(bySettingHour: adjustedHour, minute: 0, second: 0, of: baseDate)
                title = title.replacingOccurrences(of: String(text[Range(match.range(at: 0), in: text)!]), with: "")
                break
            }
        }

        // 解析分钟（如 1点30分）
        if let minuteRegex = try? NSRegularExpression(pattern: "([0-9]+)点([0-9]+)分", options: []),
           let minuteMatch = minuteRegex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
           let hourRange = Range(minuteMatch.range(at: 1), in: text),
           let minuteRange = Range(minuteMatch.range(at: 2), in: text),
           let hour = Int(text[hourRange]),
           let minute = Int(text[minuteRange]) {
            let baseDate = dueDate ?? calendar.startOfDay(for: now)
            dueDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate)
        }

        // 解析地点（在xxx）
        let locationPatterns = [
            "在(.+?)(开会|见面|等|做|进行)",
            "去(.+?)(开会|见面|等|做|进行)",
            "到(.+?)(开会|见面|等|做|进行)",
            "在(.+?)[，。]",
            "在(.+?)$"
        ]
        for pattern in locationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
               let range = Range(match.range(at: 1), in: text) {
                location = String(text[range]).trimmingCharacters(in: .whitespaces)
                title = title.replacingOccurrences(of: String(text[Range(match.range(at: 0), in: text)!]), with: "")
                break
            }
        }

        // 清理标题中的常见动词和助词
        let cleanupWords = ["创建任务", "添加任务", "新建任务", "设置任务", "安排", "提醒", "我", "要", "请", "帮我", "给我", "一下", "一个"]
        for word in cleanupWords {
            title = title.replacingOccurrences(of: word, with: "")
        }

        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "，。！？、"))

        if title.isEmpty {
            title = "新任务"
        }

        if let loc = location {
            description = "地点：\(loc)"
        }

        return ParsedTaskInfo(title: title, dueDate: dueDate, location: location, description: description)
    }

    /// 从 AI 响应中解析任务创建意图
    private func parseTaskFromAIResponse(_ response: String, originalInput: String) -> ParsedTaskInfo? {
        let createIndicators = ["已创建", "已设置", "已添加", "已安排", "已为您创建", "已帮您设置"]
        let hasCreateIndicator = createIndicators.contains { response.contains($0) }

        if hasCreateIndicator {
            return parseNaturalLanguageTask(originalInput)
        }
        return nil
    }

    /// 实际创建任务
    private func createTaskFromParsed(_ info: ParsedTaskInfo) {
        let newTask = TaskItem(
            title: info.title,
            description: info.description,
            priority: info.priority,
            status: .pending,
            dueDate: info.dueDate
        )
        taskStore.addTask(newTask)
        let msg = ChatMessage(role: .assistant, content: "✅ 已成功创建任务「\(info.title)」" +
            (info.dueDate != nil ? "，截止时间：\(formatDate(info.dueDate!))" : "") +
            (info.location != nil ? "，地点：\(info.location!)" : ""))
        messages.append(msg)
        AIManager.shared.chatHistory.append(msg)
    }

    // MARK: - Local Response Generation

    private func generateLocalResponse(to message: String) -> String {
        let tasks = taskStore.tasks
        let totalTasks = tasks.count
        let completedCount = tasks.filter { $0.status == .completed }.count
        let overdueCount = taskStore.getOverdueTasks().count
        let todayTasks = taskStore.getTasksForDate(Date())
        let highPriority = tasks.filter { ($0.priority == .high || $0.priority == .urgent) && $0.status != .completed }
        let pendingTasks = tasks.filter { $0.status == .pending }
        let inProgressTasks = tasks.filter { $0.status == .inProgress }

        if message.contains("分析") {
            if totalTasks == 0 {
                return "您目前还没有任何任务。建议先添加一些任务，我可以帮您更好地分析和规划。"
            }
            var analysis = "📊 任务分析报告\n\n"
            analysis += "总任务数：\(totalTasks)\n"
            analysis += "已完成：\(completedCount) (\(totalTasks > 0 ? Int(Double(completedCount) / Double(totalTasks) * 100) : 0)%)\n"
            analysis += "进行中：\(inProgressTasks.count)\n"
            analysis += "待办：\(pendingTasks.count)\n"
            analysis += "逾期：\(overdueCount)\n"
            if !highPriority.isEmpty {
                analysis += "\n⚠️ 高优先级任务（\(highPriority.count)项）：\n"
                for task in highPriority.prefix(5) {
                    analysis += "  • \(task.title)\n"
                }
            }
            if overdueCount > 0 {
                analysis += "\n🔴 建议：您有 \(overdueCount) 项逾期任务，建议优先处理。"
            }
            return analysis
        } else if message.contains("建议") {
            var suggestions = "💡 任务建议\n\n"
            if totalTasks == 0 {
                suggestions += "您还没有任务，以下是一些创建任务的建议：\n"
                suggestions += "1. 制定每日工作计划\n"
                suggestions += "2. 设定本周目标\n"
                suggestions += "3. 规划学习计划\n"
                suggestions += "4. 安排健康锻炼\n"
                suggestions += "5. 整理待办事项\n"
            } else {
                suggestions += "基于您当前的任务情况：\n\n"
                if pendingTasks.count > 3 {
                    suggestions += "• 待办任务较多（\(pendingTasks.count)项），建议按优先级排序处理\n"
                }
                if inProgressTasks.count > 3 {
                    suggestions += "• 进行中任务较多（\(inProgressTasks.count)项），建议集中精力逐个完成\n"
                }
                suggestions += "• 建议将大任务拆分为小步骤\n"
                suggestions += "• 为每个任务设置明确的截止日期\n"
                suggestions += "• 使用番茄工作法提高效率\n"
                suggestions += "• 每日回顾，及时调整优先级"
            }
            return suggestions
        } else if message.contains("总结") {
            if totalTasks == 0 {
                return "📋 今日总结\n\n今天还没有任务记录。建议每天创建任务来跟踪工作进度，这样我可以为您提供更有价值的总结。"
            }
            var summary = "📋 今日总结\n\n"
            summary += "今日任务：\(todayTasks.count) 项\n"
            let todayCompleted = todayTasks.filter { $0.status == .completed }.count
            summary += "已完成：\(todayCompleted) 项\n"
            summary += "待完成：\(todayTasks.count - todayCompleted) 项\n"
            summary += "\n整体完成情况：\(completedCount)/\(totalTasks)\n"
            if overdueCount > 0 {
                summary += "\n⚠️ 注意：有 \(overdueCount) 项逾期任务需要关注"
            }
            if todayCompleted == todayTasks.count && todayTasks.count > 0 {
                summary += "\n🎉 太棒了！今天的任务全部完成！"
            }
            return summary
        } else if message.contains("优化") {
            var plan = "🔄 计划优化建议\n\n"
            if totalTasks == 0 {
                plan += "暂无任务可优化。添加任务后，我可以帮您分析和优化计划。"
            } else {
                plan += "1. 优先处理逾期和高优先级任务\n"
                if overdueCount > 0 {
                    plan += "2. 您有 \(overdueCount) 项逾期任务，建议立即处理\n"
                }
                plan += "3. 将相似任务归类，批量处理\n"
                plan += "4. 为重复性任务设置自动提醒\n"
                plan += "5. 每天预留 30 分钟处理突发任务\n"
                plan += "6. 使用看板视图跟踪任务进度"
            }
            return plan
        } else if message.contains("时间管理") {
            return "⏰ 时间管理建议\n\n" +
                "1. 番茄工作法：25分钟专注 + 5分钟休息\n" +
                "2. 二八法则：80%的成果来自20%的努力\n" +
                "3. 时间块：将一天分为专注时段和处理时段\n" +
                "4. 两分钟法则：如果任务2分钟内能完成，立即做\n" +
                "5. 批处理：将相似任务集中在同一时段处理\n" +
                "6. 每日规划：前一天晚上规划第二天的任务"
        } else if message.contains("周报") {
            var report = "📄 本周工作周报\n\n"
            let calendar = Calendar.current
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
            let weekTasks = tasks.filter { $0.createdAt >= weekStart }
            let weekCompleted = weekTasks.filter { $0.status == .completed }
            report += "本周新增任务：\(weekTasks.count) 项\n"
            report += "本周完成：\(weekCompleted.count) 项\n"
            report += "完成率：\(weekTasks.count > 0 ? Int(Double(weekCompleted.count) / Double(weekTasks.count) * 100) : 0)%\n"
            if overdueCount > 0 {
                report += "\n逾期任务：\(overdueCount) 项\n"
            }
            report += "\n建议：继续保持良好的任务管理习惯！"
            return report
        } else if message.contains("逾期") {
            let overdue = taskStore.getOverdueTasks()
            if overdue.isEmpty {
                return "✅ 没有逾期任务，做得很好！继续保持。"
            }
            var analysis = "⚠️ 逾期任务分析\n\n"
            analysis += "共有 \(overdue.count) 项逾期任务：\n\n"
            for task in overdue.prefix(10) {
                analysis += "• \(task.title)"
                if let dueDate = task.dueDate {
                    let days = Calendar.current.dateComponents([.day], from: dueDate, to: Date()).day ?? 0
                    analysis += "（逾期 \(days) 天）"
                }
                analysis += "\n"
            }
            analysis += "\n建议：\n1. 立即评估逾期任务是否仍需完成\n2. 重新设定合理的截止日期\n3. 考虑降低优先级或委派他人"
            return analysis
        } else if message.contains("专注") {
            return "🧠 提高专注力的建议\n\n" +
                "1. 关闭不必要的通知推送\n" +
                "2. 使用番茄工作法（25分钟专注）\n" +
                "3. 每次只处理一个任务\n" +
                "4. 创建安静的工作环境\n" +
                "5. 定时休息，避免疲劳\n" +
                "6. 设定明确的每日目标\n" +
                "7. 完成重要任务后给自己奖励"
        }
        return "收到您的消息，我会尽力帮助您。您可以试试上方的快捷按钮，或直接描述您的需求。例如：\n• \"明天下午1点在2号会议室开会\"\n• \"删除xxx任务\"\n• \"完成xxx任务\""
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "今天 HH:mm"
        } else if Calendar.current.isDateInTomorrow(date) {
            formatter.dateFormat = "明天 HH:mm"
        } else {
            formatter.dateFormat = "MM月dd日 HH:mm"
        }
        return formatter.string(from: date)
    }
}

// MARK: - TaskEditSheet

/// 任务编辑弹窗（简化版）
struct TaskEditSheet: View {
    let task: TaskItem
    var onSave: (TaskItem) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var priority: TaskPriority
    @State private var dueDate: Date
    @State private var hasDueDate: Bool

    init(task: TaskItem, onSave: @escaping (TaskItem) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task.title)
        _description = State(initialValue: task.description)
        _priority = State(initialValue: task.priority)
        _dueDate = State(initialValue: task.dueDate ?? Date())
        _hasDueDate = State(initialValue: task.dueDate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("任务信息") {
                    TextField("标题", text: $title)
                    TextField("描述", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("优先级") {
                    Picker("优先级", selection: $priority) {
                        ForEach(TaskPriority.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("截止时间") {
                    Toggle("设置截止时间", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("截止时间", selection: $dueDate)
                    }
                }
            }
            .navigationTitle("编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var updated = task
                        updated.title = title
                        updated.description = description
                        updated.priority = priority
                        updated.dueDate = hasDueDate ? dueDate : nil
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - MessageBubble

struct MessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack {
            if isUser {
                Spacer()
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(isUser ? Color.themePrimary : Color(.systemGray5))
                    .foregroundStyle(isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(DateFormatterCache.shared.format(message.timestamp, style: .time))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            if !isUser {
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - QuickActionButton

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.themePrimary.opacity(0.1))
            .foregroundStyle(Color.themePrimary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Preview

#Preview {
    AIAssistantView()
        .environment(TaskStore.shared)
}
