import Foundation

// MARK: - SubTaskTemplate

struct SubTaskTemplate: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var defaultPriority: TaskPriority

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        defaultPriority: TaskPriority = .medium
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.defaultPriority = defaultPriority
    }
}

// MARK: - TaskTemplate

struct TaskTemplate: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var defaultPriority: TaskPriority
    var defaultTags: [UUID]
    var subTaskTemplates: [SubTaskTemplate]

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        defaultPriority: TaskPriority = .medium,
        defaultTags: [UUID] = [],
        subTaskTemplates: [SubTaskTemplate] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.defaultPriority = defaultPriority
        self.defaultTags = defaultTags
        self.subTaskTemplates = subTaskTemplates
    }
}

// MARK: - TaskTemplateManager

@MainActor
@Observable
final class TaskTemplateManager {

    // MARK: - Singleton

    static let shared = TaskTemplateManager()

    // MARK: - Properties

    var templates: [TaskTemplate] = []

    // MARK: - Preset Templates

    private static let dailyTaskTemplate = TaskTemplate(
        name: "日常任务",
        description: "用于记录每日例行事务",
        defaultPriority: .low,
        subTaskTemplates: [
            SubTaskTemplate(title: "晨间准备", defaultPriority: .low),
            SubTaskTemplate(title: "工作/学习", defaultPriority: .medium),
            SubTaskTemplate(title: "晚间总结", defaultPriority: .low)
        ]
    )

    private static let projectTaskTemplate = TaskTemplate(
        name: "项目任务",
        description: "适用于项目管理与团队协作",
        defaultPriority: .high,
        subTaskTemplates: [
            SubTaskTemplate(title: "需求分析", defaultPriority: .high),
            SubTaskTemplate(title: "方案设计", defaultPriority: .high),
            SubTaskTemplate(title: "开发实现", defaultPriority: .medium),
            SubTaskTemplate(title: "测试验收", defaultPriority: .medium),
            SubTaskTemplate(title: "上线部署", defaultPriority: .urgent)
        ]
    )

    private static let studyPlanTemplate = TaskTemplate(
        name: "学习计划",
        description: "帮助规划学习目标与进度",
        defaultPriority: .medium,
        subTaskTemplates: [
            SubTaskTemplate(title: "预习材料", defaultPriority: .low),
            SubTaskTemplate(title: "核心学习", defaultPriority: .high),
            SubTaskTemplate(title: "笔记整理", defaultPriority: .medium),
            SubTaskTemplate(title: "复习巩固", defaultPriority: .medium)
        ]
    )

    private static let fitnessPlanTemplate = TaskTemplate(
        name: "健身计划",
        description: "记录健身目标与训练安排",
        defaultPriority: .medium,
        subTaskTemplates: [
            SubTaskTemplate(title: "热身运动", defaultPriority: .low),
            SubTaskTemplate(title: "核心训练", defaultPriority: .high),
            SubTaskTemplate(title: "有氧/力量", defaultPriority: .high),
            SubTaskTemplate(title: "拉伸放松", defaultPriority: .low)
        ]
    )

    private static let meetingNotesTemplate = TaskTemplate(
        name: "会议记录",
        description: "标准化会议记录模板",
        defaultPriority: .medium,
        subTaskTemplates: [
            SubTaskTemplate(title: "会议议题", defaultPriority: .high),
            SubTaskTemplate(title: "讨论内容", defaultPriority: .medium),
            SubTaskTemplate(title: "决议事项", defaultPriority: .high),
            SubTaskTemplate(title: "后续行动", defaultPriority: .urgent)
        ]
    )

    static var presetTemplates: [TaskTemplate] {
        [
            dailyTaskTemplate,
            projectTaskTemplate,
            studyPlanTemplate,
            fitnessPlanTemplate,
            meetingNotesTemplate
        ]
    }

    // MARK: - Initialization

    private init() {
        loadTemplates()
        if templates.isEmpty {
            templates = Self.presetTemplates
            saveTemplates()
        }
    }

    // MARK: - Persistence

    private let templatesKey = "com.chengfengplan.tasktemplates"

    private func loadTemplates() {
        guard let data = UserDefaults.standard.data(forKey: templatesKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([TaskTemplate].self, from: data)
            templates = decoded
        } catch {
            print("[TaskTemplateManager] Failed to load templates: \(error)")
        }
    }

    private func saveTemplates() {
        do {
            let data = try JSONEncoder().encode(templates)
            UserDefaults.standard.set(data, forKey: templatesKey)
        } catch {
            print("[TaskTemplateManager] Failed to save templates: \(error)")
        }
    }

    // MARK: - CRUD Operations

    func addTemplate(_ template: TaskTemplate) {
        templates.append(template)
        saveTemplates()
    }

    func updateTemplate(_ template: TaskTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
            saveTemplates()
        }
    }

    func removeTemplate(id: UUID) {
        templates.removeAll { $0.id == id }
        saveTemplates()
    }

    func resetToPresets() {
        templates = Self.presetTemplates
        saveTemplates()
    }

    // MARK: - Task Creation

    /// 从模板创建任务，同时创建关联的子任务
    func createTaskFromTemplate(
        templateId: UUID,
        title: String? = nil,
        description: String? = nil,
        dueDate: Date? = nil,
        tags: [UUID]? = nil
    ) -> (task: TaskItem, subTasks: [TaskItem]) {
        guard let template = templates.first(where: { $0.id == templateId }) else {
            let fallback = TaskItem(title: title ?? "新任务")
            return (fallback, [])
        }

        let mainTask = TaskItem(
            title: title ?? template.name,
            description: description ?? template.description,
            priority: template.defaultPriority,
            dueDate: dueDate,
            tags: tags ?? template.defaultTags
        )

        var subTasks: [TaskItem] = []
        for subTemplate in template.subTaskTemplates {
            let subTask = TaskItem(
                title: subTemplate.title,
                description: subTemplate.description,
                priority: subTemplate.defaultPriority,
                parentTaskId: mainTask.id
            )
            subTasks.append(subTask)
            mainTask.addSubTask(subTask.id)
        }

        return (mainTask, subTasks)
    }

    /// 根据模板名称快速创建任务
    func createTaskFromTemplate(
        name: String,
        title: String? = nil,
        description: String? = nil,
        dueDate: Date? = nil,
        tags: [UUID]? = nil
    ) -> (task: TaskItem, subTasks: [TaskItem]) {
        let template = templates.first { $0.name == name }
        if let template = template {
            return createTaskFromTemplate(
                templateId: template.id,
                title: title,
                description: description,
                dueDate: dueDate,
                tags: tags
            )
        }
        let fallback = TaskItem(title: title ?? name)
        return (fallback, [])
    }
}
