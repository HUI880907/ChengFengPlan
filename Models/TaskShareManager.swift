import Foundation
import UIKit

// MARK: - ShareFormat

enum ShareFormat: String, Codable, CaseIterable, Identifiable {
    case json = "json"
    case text = "text"
    case url = "url"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .text: return "文本"
        case .url: return "链接"
        }
    }

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .text: return "txt"
        case .url: return "url"
        }
    }

    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .text: return "text/plain"
        case .url: return "text/plain"
        }
    }
}

// MARK: - TaskShareData

struct TaskShareData: Codable {
    let version: String
    let exportedAt: Date
    let tasks: [TaskItem]

    init(tasks: [TaskItem], version: String = "1.0") {
        self.version = version
        self.exportedAt = Date()
        self.tasks = tasks
    }
}

// MARK: - TaskShareError

enum TaskShareError: Error, LocalizedError {
    case encodingFailed
    case decodingFailed
    case invalidData
    case invalidURL
    case shareFailed
    case noTasksProvided

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "编码失败"
        case .decodingFailed: return "解码失败"
        case .invalidData: return "无效的数据"
        case .invalidURL: return "无效的链接"
        case .shareFailed: return "分享失败"
        case .noTasksProvided: return "未提供任务"
        }
    }
}

// MARK: - TaskShareManager

@MainActor
final class TaskShareManager {

    // MARK: - Singleton

    static let shared = TaskShareManager()

    // MARK: - Properties

    private let baseShareURL = "https://chengfengplan.app/share/task"

    // MARK: - Initialization

    private init() {}

    // MARK: - Share Task

    /// 分享单个任务
    func shareTask(_ task: TaskItem, format: ShareFormat) throws -> ShareResult {
        return try shareTasks([task], format: format)
    }

    /// 分享多个任务
    func shareTasks(_ tasks: [TaskItem], format: ShareFormat) throws -> ShareResult {
        guard !tasks.isEmpty else {
            throw TaskShareError.noTasksProvided
        }

        switch format {
        case .json:
            return try generateJSONShare(tasks: tasks)
        case .text:
            return generateTextShare(tasks: tasks)
        case .url:
            return try generateURLShare(tasks: tasks)
        }
    }

    // MARK: - Import Task

    /// 从数据导入任务
    func importTask(from data: Data) throws -> [TaskItem] {
        let decoder = JSONDecoder()

        // 首先尝试解析为 TaskShareData
        if let shareData = try? decoder.decode(TaskShareData.self, from: data) {
            return shareData.tasks
        }

        // 尝试解析为单个任务
        if let singleTask = try? decoder.decode(TaskItem.self, from: data) {
            return [singleTask]
        }

        // 尝试解析为任务数组
        if let tasks = try? decoder.decode([TaskItem].self, from: data) {
            return tasks
        }

        throw TaskShareError.decodingFailed
    }

    /// 从 JSON 字符串导入任务
    func importTask(from jsonString: String) throws -> [TaskItem] {
        guard let data = jsonString.data(using: .utf8) else {
            throw TaskShareError.invalidData
        }
        return try importTask(from: data)
    }

    // MARK: - Generate Share URL

    /// 生成任务分享链接
    func generateShareURL(for task: TaskItem) throws -> URL {
        let encoder = JSONEncoder()
        let taskData = try encoder.encode(task)
        let base64String = taskData.base64EncodedString()
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""

        var components = URLComponents(string: baseShareURL)
        components?.queryItems = [
            URLQueryItem(name: "data", value: base64String)
        ]

        guard let url = components?.url else {
            throw TaskShareError.invalidURL
        }
        return url
    }

    /// 从分享链接解析任务
    func parseTask(from url: URL) throws -> TaskItem {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let dataItem = components.queryItems?.first(where: { $0.name == "data" }),
              let base64String = dataItem.value,
              let taskData = Data(base64Encoded: base64String) else {
            throw TaskShareError.invalidData
        }

        let decoder = JSONDecoder()
        return try decoder.decode(TaskItem.self, from: taskData)
    }

    // MARK: - Private Helpers

    private func generateJSONShare(tasks: [TaskItem]) throws -> ShareResult {
        let shareData = TaskShareData(tasks: tasks)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(shareData)

        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw TaskShareError.encodingFailed
        }

        return ShareResult(
            data: data,
            text: jsonString,
            fileName: "chengfeng_tasks_\(Date().timeIntervalSince1970).json",
            mimeType: ShareFormat.json.mimeType
        )
    }

    private func generateTextShare(tasks: [TaskItem]) -> ShareResult {
        var lines: [String] = []
        lines.append("===== 乘风计划 - 任务分享 =====")
        lines.append("")

        for (index, task) in tasks.enumerated() {
            lines.append("[\(index + 1)] \(task.title)")
            if !task.description.isEmpty {
                lines.append("    描述: \(task.description)")
            }
            lines.append("    优先级: \(task.priority.displayName)")
            lines.append("    状态: \(task.status.displayName)")
            if let dueDate = task.dueDate {
                lines.append("    截止日期: \(formatDate(dueDate))")
            }
            if !task.aiSuggestions.isEmpty {
                lines.append("    AI 建议: \(task.aiSuggestions.joined(separator: ", "))")
            }
            lines.append("")
        }

        lines.append("===== 由乘风计划生成 =====")

        let text = lines.joined(separator: "\n")
        let data = text.data(using: .utf8) ?? Data()

        return ShareResult(
            data: data,
            text: text,
            fileName: "chengfeng_tasks_\(Date().timeIntervalSince1970).txt",
            mimeType: ShareFormat.text.mimeType
        )
    }

    private func generateURLShare(tasks: [TaskItem]) throws -> ShareResult {
        guard let firstTask = tasks.first else {
            throw TaskShareError.noTasksProvided
        }

        let url = try generateShareURL(for: firstTask)
        let text = url.absoluteString
        let data = text.data(using: .utf8) ?? Data()

        return ShareResult(
            data: data,
            text: text,
            fileName: "chengfeng_task.url",
            mimeType: ShareFormat.url.mimeType
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - ShareResult

struct ShareResult {
    let data: Data
    let text: String
    let fileName: String
    let mimeType: String

    var activityItems: [Any] {
        [data as Any, text as Any]
    }
}

// MARK: - UIActivityViewController Helper

extension TaskShareManager {
    /// 获取用于分享的 UIActivityViewController
    func getShareActivityController(for result: ShareResult) -> UIActivityViewController {
        let activityItems: [Any] = [result.data, result.text]
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }

    /// 直接分享任务（返回 UIActivityViewController）
    func shareTaskActivityController(_ task: TaskItem, format: ShareFormat) throws -> UIActivityViewController {
        let result = try shareTask(task, format: format)
        return getShareActivityController(for: result)
    }

    /// 直接分享多个任务（返回 UIActivityViewController）
    func shareTasksActivityController(_ tasks: [TaskItem], format: ShareFormat) throws -> UIActivityViewController {
        let result = try shareTasks(tasks, format: format)
        return getShareActivityController(for: result)
    }
}
