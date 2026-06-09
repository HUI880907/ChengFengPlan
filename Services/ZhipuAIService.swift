// MARK: - Imports
import Foundation

// MARK: - AI Service Errors

enum AIServiceError: Error, LocalizedError {
    case invalidURL
    case invalidAPIKey
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case apiError(String)
    case streamingNotSupported

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的请求 URL"
        case .invalidAPIKey:
            return "API 密钥无效或为空"
        case .requestFailed(let error):
            return "请求失败: \(error.localizedDescription)"
        case .invalidResponse:
            return "服务器返回了无效的响应"
        case .decodingFailed(let error):
            return "解析响应失败: \(error.localizedDescription)"
        case .apiError(let message):
            return "API 错误: \(message)"
        case .streamingNotSupported:
            return "当前提供商不支持流式响应"
        }
    }
}

// MARK: - Base AIService

/// AI 服务基类，包含通用网络请求逻辑
class BaseAIService: AIServiceProtocol, @unchecked Sendable {
    let provider: AIProvider
    let baseURL: String
    let apiKey: String

    private let urlSession: URLSession

    init(provider: AIProvider, baseURL: String, apiKey: String) {
        self.provider = provider
        self.baseURL = baseURL
        self.apiKey = apiKey

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.urlSession = URLSession(configuration: config)
    }

    // MARK: - AIServiceProtocol

    func chat(prompt: String, systemPrompt: String?) async -> AIResponse {
        guard !apiKey.isEmpty else {
            return .failure(AIServiceError.invalidAPIKey.localizedDescription)
        }

        do {
            let request = try buildRequest(prompt: prompt, systemPrompt: systemPrompt)
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(AIServiceError.invalidResponse.localizedDescription)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorBody = String(data: data, encoding: .utf8) ?? "未知错误"
                return .failure("HTTP \(httpResponse.statusCode): \(errorBody)")
            }

            return try parseResponse(data: data)
        } catch let error as AIServiceError {
            return .failure(error.localizedDescription)
        } catch {
            return .failure(AIServiceError.requestFailed(error).localizedDescription)
        }
    }

    func validateAPIKey() async -> Bool {
        let response = await chat(prompt: "Hello", systemPrompt: nil)
        return response.isSuccess
    }

    // MARK: - Overridable Methods

    func buildRequest(prompt: String, systemPrompt: String?) throws -> URLRequest {
        guard let url = URL(string: baseURL) else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = buildRequestBody(prompt: prompt, systemPrompt: systemPrompt)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return request
    }

    func buildRequestBody(prompt: String, systemPrompt: String?) -> [String: Any] {
        var messages: [[String: String]] = []
        if let system = systemPrompt {
            messages.append(["role": "system", "content": system])
        }
        messages.append(["role": "user", "content": prompt])

        return [
            "model": defaultModelName(),
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 2048
        ]
    }

    func parseResponse(data: Data) throws -> AIResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIServiceError.invalidResponse
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw AIServiceError.apiError(message)
        }

        guard let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.invalidResponse
        }

        return AIResponse(content: content)
    }

    func defaultModelName() -> String {
        "default"
    }

    // MARK: - Streaming (Optional)

    func chatStream(prompt: String, systemPrompt: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIServiceError.streamingNotSupported)
        }
    }
}

// MARK: - ZhipuAIService

final class ZhipuAIService: BaseAIService {
    init(apiKey: String) {
        super.init(provider: .zhipu, baseURL: AIProvider.zhipu.defaultBaseURL, apiKey: apiKey)
    }

    override func defaultModelName() -> String {
        return "glm-4"
    }
}

// MARK: - TongyiAIService

final class TongyiAIService: BaseAIService {
    init(apiKey: String) {
        super.init(provider: .tongyi, baseURL: AIProvider.tongyi.defaultBaseURL, apiKey: apiKey)
    }

    override func defaultModelName() -> String {
        return "qwen-turbo"
    }

    override func buildRequest(prompt: String, systemPrompt: String?) throws -> URLRequest {
        guard let url = URL(string: baseURL) else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": defaultModelName(),
            "input": [
                "messages": [
                    ["role": "system", "content": systemPrompt ?? "You are a helpful assistant"],
                    ["role": "user", "content": prompt]
                ]
            ],
            "parameters": [
                "result_format": "message",
                "max_tokens": 2048,
                "temperature": 0.7
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    override func parseResponse(data: Data) throws -> AIResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIServiceError.invalidResponse
        }

        if let errorMessage = json["message"] as? String {
            throw AIServiceError.apiError(errorMessage)
        }

        guard let output = json["output"] as? [String: Any],
              let choices = output["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.invalidResponse
        }

        return AIResponse(content: content)
    }
}

// MARK: - WenxinAIService

final class WenxinAIService: BaseAIService {
    init(apiKey: String) {
        super.init(provider: .wenxin, baseURL: AIProvider.wenxin.defaultBaseURL, apiKey: apiKey)
    }

    override func defaultModelName() -> String {
        return "ernie-bot"
    }
}

// MARK: - SparkAIService

final class SparkAIService: BaseAIService {
    init(apiKey: String) {
        super.init(provider: .spark, baseURL: AIProvider.spark.defaultBaseURL, apiKey: apiKey)
    }

    override func defaultModelName() -> String {
        return "generalv3.5"
    }
}

// MARK: - MoonshotAIService

final class MoonshotAIService: BaseAIService {
    init(apiKey: String) {
        super.init(provider: .moonshot, baseURL: AIProvider.moonshot.defaultBaseURL, apiKey: apiKey)
    }

    override func defaultModelName() -> String {
        return "moonshot-v1-8k"
    }
}

// MARK: - MinimaxAIService

final class MinimaxAIService: BaseAIService {
    init(apiKey: String) {
        super.init(provider: .minimax, baseURL: AIProvider.minimax.defaultBaseURL, apiKey: apiKey)
    }

    override func defaultModelName() -> String {
        return "abab6.5-chat"
    }

    override func buildRequestBody(prompt: String, systemPrompt: String?) -> [String: Any] {
        var messages: [[String: String]] = []
        if let system = systemPrompt {
            messages.append(["role": "system", "content": system])
        }
        messages.append(["role": "user", "content": prompt])

        return [
            "model": defaultModelName(),
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 2048
        ]
    }
}

// MARK: - ZeroOneAIService

final class ZeroOneAIService: BaseAIService {
    init(apiKey: String) {
        super.init(provider: .zeroOne, baseURL: AIProvider.zeroOne.defaultBaseURL, apiKey: apiKey)
    }

    override func defaultModelName() -> String {
        return "yi-large"
    }
}

// MARK: - CustomAIService

final class CustomAIService: BaseAIService {
    private var modelName: String

    init(baseURL: String, apiKey: String, modelName: String) {
        self.modelName = modelName
        super.init(provider: .custom, baseURL: baseURL, apiKey: apiKey)
    }

    override func defaultModelName() -> String {
        return modelName
    }
}
