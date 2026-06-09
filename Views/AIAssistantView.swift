// MARK: - AIAssistantView.swift
// 乘风计划 - AI 助手聊天视图

import SwiftUI

// MARK: - AIAssistantView

struct AIAssistantView: View {
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

        // 模拟 AI 回复
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let response = generateAIResponse(to: text)
            messages.append(ChatMessage(role: .assistant, content: response))
            isLoading = false
        }
    }

    private func sendQuickMessage(_ text: String) {
        inputText = text
        sendMessage()
    }

    private func generateAIResponse(to message: String) -> String {
        if message.contains("分析") {
            return "根据您的任务数据分析，您目前有 5 个高优先级任务待完成，建议优先处理逾期的项目报告。"
        } else if message.contains("建议") {
            return "建议您：\n1. 将大任务拆分为小步骤\n2. 设置明确的截止日期\n3. 使用番茄工作法提高效率"
        } else if message.contains("总结") {
            return "今天您完成了 3 个任务，还有 2 个待办。整体效率不错，继续保持！"
        }
        return "收到您的消息，我会尽力帮助您。请告诉我更多细节。"
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
}
