import Foundation

// MARK: - SortOption

enum SortOption: String, Codable, CaseIterable, Identifiable {
    case dueDate = "截止日期"
    case priority = "优先级"
    case title = "标题"
    case createdAt = "创建时间"
    case custom = "自定义"

    var id: String { rawValue }
}

// MARK: - RecurrenceRule

enum RecurrenceRule: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "不重复"
        case .daily: return "每天"
        case .weekly: return "每周"
        case .monthly: return "每月"
        case .yearly: return "每年"
        }
    }
}

// MARK: - TaskPriority

enum TaskPriority: String, Codable, CaseIterable, Identifiable, Comparable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .urgent: return "紧急"
        }
    }

    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }

    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - TaskStatus

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "pending"
    case inProgress = "inProgress"
    case completed = "completed"
    case cancelled = "cancelled"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending: return "待办"
        case .inProgress: return "进行中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        }
    }
}

// MARK: - Attachment

struct Attachment: Identifiable, Codable, Equatable {
    let id: UUID
    var filename: String
    var data: Data
    let createdAt: Date

    init(id: UUID = UUID(), filename: String, data: Data, createdAt: Date = Date()) {
        self.id = id
        self.filename = filename
        self.data = data
        self.createdAt = createdAt
    }
}

// MARK: - LogEntry

struct LogEntry: Identifiable, Codable, Equatable {
    enum LogType: String, Codable, CaseIterable, Identifiable {
        case note = "note"
        case progress = "progress"
        case issue = "issue"
        case milestone = "milestone"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .note: return "笔记"
            case .progress: return "进度"
            case .issue: return "问题"
            case .milestone: return "里程碑"
            }
        }
    }

    let id: UUID
    var content: String
    let createdAt: Date
    var type: LogType

    init(id: UUID = UUID(), content: String, createdAt: Date = Date(), type: LogType = .note) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.type = type
    }
}

// MARK: - RecurringRule

struct RecurringRule: Codable, Equatable {
    enum Frequency: String, Codable, CaseIterable, Identifiable {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"
        case yearly = "yearly"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .daily: return "每天"
            case .weekly: return "每周"
            case .monthly: return "每月"
            case .yearly: return "每年"
            }
        }
    }

    var frequency: Frequency
    var interval: Int
    var endDate: Date?

    init(frequency: Frequency = .daily, interval: Int = 1, endDate: Date? = nil) {
        self.frequency = frequency
        self.interval = interval
        self.endDate = endDate
    }
}

// MARK: - TaskItem

@Observable
final class TaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var priority: TaskPriority
    var status: TaskStatus
    let createdAt: Date
    var updatedAt: Date
    var dueDate: Date?
    var reminderDate: Date?
    var completedAt: Date?
    var tags: [UUID]
    var parentTaskId: UUID?
    var subTaskIds: [UUID]
    var attachments: [Attachment]
    var logEntries: [LogEntry]
    var isRecurring: Bool
    var recurrence: RecurrenceRule
    var recurringRule: RecurringRule?
    var aiSuggestions: [String]
    var aiGenerated: Bool

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        priority: TaskPriority = .medium,
        status: TaskStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        dueDate: Date? = nil,
        reminderDate: Date? = nil,
        completedAt: Date? = nil,
        tags: [UUID] = [],
        parentTaskId: UUID? = nil,
        subTaskIds: [UUID] = [],
        attachments: [Attachment] = [],
        logEntries: [LogEntry] = [],
        isRecurring: Bool = false,
        recurrence: RecurrenceRule = .none,
        recurringRule: RecurringRule? = nil,
        aiSuggestions: [String] = [],
        aiGenerated: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.priority = priority
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.dueDate = dueDate
        self.reminderDate = reminderDate
        self.completedAt = completedAt
        self.tags = tags
        self.parentTaskId = parentTaskId
        self.subTaskIds = subTaskIds
        self.attachments = attachments
        self.logEntries = logEntries
        self.isRecurring = isRecurring
        self.recurrence = recurrence
        self.recurringRule = recurringRule
        self.aiSuggestions = aiSuggestions
        self.aiGenerated = aiGenerated
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case priority
        case status
        case createdAt
        case updatedAt
        case dueDate
        case reminderDate
        case completedAt
        case tags
        case parentTaskId
        case subTaskIds
        case attachments
        case logEntries
        case isRecurring
        case recurrence
        case recurringRule
        case aiSuggestions
        case aiGenerated
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        priority = try container.decode(TaskPriority.self, forKey: .priority)
        status = try container.decode(TaskStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        reminderDate = try container.decodeIfPresent(Date.self, forKey: .reminderDate)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        tags = try container.decode([UUID].self, forKey: .tags)
        parentTaskId = try container.decodeIfPresent(UUID.self, forKey: .parentTaskId)
        subTaskIds = try container.decode([UUID].self, forKey: .subTaskIds)
        attachments = try container.decode([Attachment].self, forKey: .attachments)
        logEntries = try container.decode([LogEntry].self, forKey: .logEntries)
        isRecurring = try container.decode(Bool.self, forKey: .isRecurring)
        recurrence = try container.decode(RecurrenceRule.self, forKey: .recurrence)
        recurringRule = try container.decodeIfPresent(RecurringRule.self, forKey: .recurringRule)
        aiSuggestions = try container.decode([String].self, forKey: .aiSuggestions)
        aiGenerated = try container.decode(Bool.self, forKey: .aiGenerated)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(priority, forKey: .priority)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encode(reminderDate, forKey: .reminderDate)
        try container.encode(completedAt, forKey: .completedAt)
        try container.encode(tags, forKey: .tags)
        try container.encode(parentTaskId, forKey: .parentTaskId)
        try container.encode(subTaskIds, forKey: .subTaskIds)
        try container.encode(attachments, forKey: .attachments)
        try container.encode(logEntries, forKey: .logEntries)
        try container.encode(isRecurring, forKey: .isRecurring)
        try container.encode(recurrence, forKey: .recurrence)
        try container.encode(recurringRule, forKey: .recurringRule)
        try container.encode(aiSuggestions, forKey: .aiSuggestions)
        try container.encode(aiGenerated, forKey: .aiGenerated)
    }

    // MARK: - Equatable

    static func == (lhs: TaskItem, rhs: TaskItem) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Business Logic

    var isOverdue: Bool {
        guard let due = dueDate else { return false }
        return due < Date() && status != .completed && status != .cancelled
    }

    var isCompleted: Bool {
        status == .completed
    }

    var hasSubTasks: Bool {
        !subTaskIds.isEmpty
    }

    var hasParentTask: Bool {
        parentTaskId != nil
    }

    var daysUntilDue: Int? {
        guard let due = dueDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: due))
        return components.day
    }

    func markAsCompleted() {
        status = .completed
        completedAt = Date()
        updatedAt = Date()
    }

    func markAsInProgress() {
        status = .inProgress
        updatedAt = Date()
    }

    func markAsPending() {
        status = .pending
        updatedAt = Date()
    }

    func markAsCancelled() {
        status = .cancelled
        updatedAt = Date()
    }

    func addLogEntry(_ entry: LogEntry) {
        logEntries.append(entry)
        updatedAt = Date()
    }

    func addAttachment(_ attachment: Attachment) {
        attachments.append(attachment)
        updatedAt = Date()
    }

    func addSubTask(_ subTaskId: UUID) {
        subTaskIds.append(subTaskId)
        updatedAt = Date()
    }

    func removeSubTask(_ subTaskId: UUID) {
        subTaskIds.removeAll { $0 == subTaskId }
        updatedAt = Date()
    }

    func addTag(_ tagId: UUID) {
        if !tags.contains(tagId) {
            tags.append(tagId)
            updatedAt = Date()
        }
    }

    func removeTag(_ tagId: UUID) {
        tags.removeAll { $0 == tagId }
        updatedAt = Date()
    }

    func addAISuggestion(_ suggestion: String) {
        aiSuggestions.append(suggestion)
        updatedAt = Date()
    }
}
