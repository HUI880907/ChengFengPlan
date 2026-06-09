// MARK: - Imports
import Foundation

// MARK: - AIProvider

/// AI 服务提供商枚举
enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case zhipu = "智谱 AI"
    case tongyi = "通义千问"
    case wenxin = "文心一言"
    case spark = "讯飞星火"
    case moonshot = "Moonshot"
    case minimax = "MiniMax"
    case zeroOne = "零一万物"
    case custom = "自定义"

    var id: String { rawValue }

    var defaultBaseURL: String {
        switch self {
        case .zhipu:
            return "https://open.bigmodel.cn/api/paas/v4/chat/completions"
        case .tongyi:
            return "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation"
        case .wenxin:
            return "https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/completions"
        case .spark:
            return "https://spark-api-open.xf-yun.com/v1/chat/completions"
        case .moonshot:
            return "https://api.moonshot.cn/v1/chat/completions"
        case .minimax:
            return "https://api.minimax.chat/v1/text/chatcompletion_v2"
        case .zeroOne:
            return "https://api.01.ai/v1/chat/completions"
        case .custom:
            return ""
        }
    }
}

// MARK: - AIResponse

/// AI 响应结构体
struct AIResponse: Sendable {
    let content: String
    let isSuccess: Bool
    let errorMessage: String?

    init(content: String, isSuccess: Bool = true, errorMessage: String? = nil) {
        self.content = content
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
    }

    static func failure(_ message: String) -> AIResponse {
        AIResponse(content: "", isSuccess: false, errorMessage: message)
    }
}

// MARK: - AIServiceProtocol

/// AI 服务协议
protocol AIServiceProtocol: Sendable {
    /// 提供商类型
    var provider: AIProvider { get }

    /// 基础 URL
    var baseURL: String { get }

    /// API 密钥
    var apiKey: String { get }

    /// 发送聊天请求
    func chat(prompt: String, systemPrompt: String?) async -> AIResponse

    /// 验证 API 密钥是否有效
    func validateAPIKey() async -> Bool
}

// MARK: - AIServiceProtocol Default Implementations

extension AIServiceProtocol {
    func chat(prompt: String) async -> AIResponse {
        await chat(prompt: prompt, systemPrompt: nil)
    }
}
