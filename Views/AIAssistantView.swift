// MARK: - AIAssistantView.swift
// 乘风计划 - AI 助手聊天视图

import SwiftUI

// MARK: - AIAssistantView

@MainActor
struct AIAssistantView: View {
    @Environment(TaskStore.self) private var taskStore
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, content: "您好！我是乘风计划的 AI 助手。我可以帮您分析任务、提供建议或总结今天的工作。请问有什么可以帮您的吗？")
    ]
    @State private var inputText = ""
    @State private var isLoading = false
    @FocusState private var isInputFocused: Bool

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
        inputText = ""
        isLoading = true

        // 尝试调用真实AI，如果没有配置API Key则使用本地分析
        Task {
            let response = await AIManager.shared.chat(prompt: text)
            await MainActor.run {
                if response.isSuccess && !response.content.isEmpty {
                    messages.append(ChatMessage(role: .assistant, content: response.content))
                } else {
                    // Fallback到本地分析
                    let localResponse = generateLocalResponse(to: text)
                    messages.append(ChatMessage(role: .assistant, content: localResponse))
                }
                isLoading = false
            }
        }
    }

    private func sendQuickMessage(_ text: String) {
        inputText = text
        sendMessage()
    }

    private func generateLocalResponse(to message: String) -> String {
        let tasks = taskStore.tasks
        let totalTasks = tasks.count
        let completedCount = tasks.filter { $0.status == .completed }.count
        let overdueCount = taskStore.getOverdueTasks().count
        let todayTasks = taskStore.getTasksForDate(Date())
        let highPriority = tasks.filter { $0.priority == .high || $0.priority == .urgent && $0.status != .completed }
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
        return "收到您的消息，我会尽力帮助您。您可以试试上方的快捷按钮，或直接描述您的需求。"
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
