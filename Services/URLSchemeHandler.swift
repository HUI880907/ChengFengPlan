// MARK: - Imports
import Foundation

// MARK: - URLSchemeHandler

/// URL Scheme 处理服务
final class URLSchemeHandler {

    // MARK: - Shared Instance

    static let shared = URLSchemeHandler()

    // MARK: - Constants

    private let scheme = "chengfengplan"

    // MARK: - Initialization

    private init() {}

    // MARK: - URL Handling

    /// 处理传入的 URL
    func handle(url: URL) -> URLSchemeAction? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        guard let host = url.host?.lowercased() else { return nil }

        switch host {
        case "task":
            return parseTaskURL(url: url)
        case "add":
            return createTaskFromURL(url: url)
        default:
            return nil
        }
    }

    /// 解析任务详情 URL
    /// 格式: chengfengplan://task/{id}
    func parseTaskURL(url: URL) -> URLSchemeAction? {
        let components = url.pathComponents
        // pathComponents 格式: ["/", "{uuid}"]
        guard components.count >= 2 else { return nil }

        let idString = components[1]
        // 防止 idString 为 "/" (根路径) 的情况
        guard !idString.isEmpty, idString != "/" else { return nil }
        guard let id = UUID(uuidString: idString) else { return nil }

        return .openTask(id: id)
    }

    /// 从 URL 创建任务
    /// 格式: chengfengplan://add?title=xxx&description=yyy&priority=high&dueDate=2024-12-31
    func createTaskFromURL(url: URL) -> URLSchemeAction? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return nil }

        let params = queryItems.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        }

        guard let title = params["title"], !title.isEmpty else { return nil }

        let description = params["description"] ?? ""
        let priorityString = params["priority"] ?? "medium"
        let priority = TaskPriority(rawValue: priorityString) ?? .medium

        var dueDate: Date?
        if let dateString = params["dueDate"] {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            dueDate = formatter.date(from: dateString)
        }

        let task = TaskItem(
            title: title,
            description: description,
            priority: priority,
            dueDate: dueDate
        )

        return .addTask(task: task)
    }

    // MARK: - URL Generation

    /// 生成任务详情 URL
    func generateTaskURL(task: TaskItem) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "task"
        components.path = "/\(task.id.uuidString)"
        return components.url
    }

    /// 生成添加任务 URL
    func generateAddTaskURL(title: String, description: String? = nil, priority: TaskPriority? = nil, dueDate: Date? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "add"

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "title", value: title)
        ]

        if let description = description, !description.isEmpty {
            queryItems.append(URLQueryItem(name: "description", value: description))
        }

        if let priority = priority {
            queryItems.append(URLQueryItem(name: "priority", value: priority.rawValue))
        }

        if let dueDate = dueDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            queryItems.append(URLQueryItem(name: "dueDate", value: formatter.string(from: dueDate)))
        }

        components.queryItems = queryItems
        return components.url
    }
}

// MARK: - URLSchemeAction

/// URL Scheme 解析后的动作
enum URLSchemeAction: Equatable {
    case openTask(id: UUID)
    case addTask(task: TaskItem)

    static func == (lhs: URLSchemeAction, rhs: URLSchemeAction) -> Bool {
        switch (lhs, rhs) {
        case (.openTask(let id1), .openTask(let id2)):
            return id1 == id2
        case (.addTask(let task1), .addTask(let task2)):
            return task1.id == task2.id
        default:
            return false
        }
    }
}
