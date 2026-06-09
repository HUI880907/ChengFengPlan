// MARK: - Imports
import Foundation

// MARK: - ChatMessage

/// 聊天消息结构
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

enum MessageRole: String, Codable {
    case user, assistant, system
}

// MARK: - AIManager

/// AI 管理器：管理多个 AI 提供商，提供统一的业务接口
@Observable
@MainActor
final class AIManager {

    // MARK: - Shared Instance

    static let shared = AIManager()

    // MARK: - Published Properties

    var currentProvider: AIProvider = .zhipu
    var apiKeys: [AIProvider: String] = [:]
    var isLoading: Bool = false
    var chatHistory: [ChatMessage] = []
    var lastError: String?

    // MARK: - Private Properties

    private var currentService: AIServiceProtocol?

    // MARK: - Initialization

    private init() {
        loadAPIKeys()
        updateCurrentService()
    }

    // MARK: - Provider Management

    /// 设置指定提供商的 API 密钥
    func setAPIKey(_ key: String, for provider: AIProvider) {
        apiKeys[provider] = key
        saveAPIKeys()
        if currentProvider == provider {
            updateCurrentService()
        }
    }

    /// 切换当前提供商
    func switchProvider(to provider: AIProvider) {
        currentProvider = provider
        updateCurrentService()
    }

    // MARK: - Chat Interface

    /// 发送聊天消息（nonisolated，可从任意线程调用）
    nonisolated func chat(prompt: String) async -> AIResponse {
        let service = await MainActor.run {
            AIManager.shared.currentService
        }

        guard let service = service else {
            return .failure("未配置有效的 AI 服务")
        }

        let userMessage = ChatMessage(role: .user, content: prompt)
        await MainActor.run {
            AIManager.shared.chatHistory.append(userMessage)
            AIManager.shared.isLoading = true
            AIManager.shared.lastError = nil
        }

        let response = await service.chat(prompt: prompt, systemPrompt: await MainActor.run { getSystemPrompt() })

        await MainActor.run {
            AIManager.shared.isLoading = false
            if response.isSuccess {
                let assistantMessage = ChatMessage(role: .assistant, content: response.content)
                AIManager.shared.chatHistory.append(assistantMessage)
            } else {
                AIManager.shared.lastError = response.errorMessage
            }
        }

        return response
    }

    /// 分析任务内容
    nonisolated func analyzeTask(_ task: TaskItem) async -> AIResponse {
        let prompt = """
        请分析以下任务，并提供建议：
        标题：\(task.title)
        描述：\(task.description)
        优先级：\(task.priority.displayName)
        截止日期：\(task.dueDate != nil ? AIManager.formatDate(task.dueDate!) : "无")

        请提供：
        1. 任务拆解建议
        2. 时间规划建议
        3. 优先级评估
        """
        return await chat(prompt: prompt)
    }

    /// 根据目标建议任务
    nonisolated func suggestTasks(for goal: String) async -> AIResponse {
        let prompt = """
        用户想要达成以下目标：\(goal)

        请帮助用户将这个目标拆解为 3-5 个具体的可执行任务，每个任务包含：
        - 任务标题
        - 建议优先级（低/中/高/紧急）
        - 建议完成时间

        请以清晰的列表格式输出。
        """
        return await chat(prompt: prompt)
    }

    /// 总结一天的任务
    nonisolated func summarizeDay(tasks: [TaskItem]) async -> AIResponse {
        let completed = tasks.filter { $0.isCompleted }.count
        let total = tasks.count
        let overdue = tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due < Date() && !task.isCompleted
        }.count

        let taskList = tasks.map { "- [\($0.isCompleted ? "x" : " ")] \($0.title)" }.joined(separator: "\n")

        let prompt = """
        请根据以下今日任务列表生成一份简报：

        统计：\(completed)/\(total) 已完成，\(overdue) 个逾期

        任务列表：
        \(taskList)

        请提供：
        1. 今日完成情况总结
        2. 对未完成任务的建议
        3. 明日优先事项推荐
        """
        return await chat(prompt: prompt)
    }

    /// 清空聊天历史
    func clearChatHistory() {
        chatHistory.removeAll()
    }

    // MARK: - Private Helpers

    private func updateCurrentService() {
        guard let apiKey = apiKeys[currentProvider], !apiKey.isEmpty else {
            currentService = nil
            return
        }

        switch currentProvider {
        case .zhipu:
            currentService = ZhipuAIService(apiKey: apiKey)
        case .tongyi:
            currentService = TongyiAIService(apiKey: apiKey)
        case .wenxin:
            currentService = WenxinAIService(apiKey: apiKey)
        case .spark:
            currentService = SparkAIService(apiKey: apiKey)
        case .moonshot:
            currentService = MoonshotAIService(apiKey: apiKey)
        case .minimax:
            currentService = MinimaxAIService(apiKey: apiKey)
        case .zeroOne:
            currentService = ZeroOneAIService(apiKey: apiKey)
        case .custom:
            currentService = CustomAIService(baseURL: "", apiKey: apiKey, modelName: "custom")
        }
    }

    private func getSystemPrompt() -> String {
        return """
        你是「乘风计划」的 AI 助手，一个专注于任务管理和时间规划的智能助手。
        你的职责是帮助用户更好地管理任务、拆解目标、规划时间。
        回答应该简洁、实用、可操作。
        """
    }

    private func saveAPIKeys() {
        for (provider, key) in apiKeys {
            SecureStore.shared.saveString(key: "ai_api_key_\(provider.rawValue)", value: key)
        }
    }

    private func loadAPIKeys() {
        var keys: [AIProvider: String] = [:]
        for provider in AIProvider.allCases {
            if let key = SecureStore.shared.loadString(key: "ai_key_\(provider.rawValue)") {
                keys[provider] = key
            }
        }
        apiKeys = keys
    }

    private nonisolated static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Helpers
