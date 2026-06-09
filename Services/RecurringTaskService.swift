// MARK: - Imports
import Foundation

// MARK: - RecurringTaskService

/// 重复任务自动生成服务
final class RecurringTaskService {

    // MARK: - Shared Instance

    static let shared = RecurringTaskService()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 为重复任务生成下一次出现
    func generateNextOccurrence(task: TaskItem) -> TaskItem? {
        guard task.recurrence != .none else { return nil }
        guard let dueDate = task.dueDate else { return nil }

        let calendar = Calendar.current
        let nextDueDate: Date?

        switch task.recurrence {
        case .daily:
            nextDueDate = calendar.date(byAdding: .day, value: 1, to: dueDate)
        case .weekly:
            nextDueDate = calendar.date(byAdding: .weekOfYear, value: 1, to: dueDate)
        case .monthly:
            nextDueDate = calendar.date(byAdding: .month, value: 1, to: dueDate)
        case .yearly:
            nextDueDate = calendar.date(byAdding: .year, value: 1, to: dueDate)
        case .none:
            return nil
        }

        guard let newDueDate = nextDueDate else { return nil }

        return TaskItem(
            title: task.title,
            description: task.description,
            status: .pending,
            priority: task.priority,
            dueDate: newDueDate,
            tags: task.tags,
            parentTaskId: task.parentTaskId,
            recurrence: task.recurrence,
            aiGenerated: false
        )
    }

    /// 判断任务是否应该生成下一次出现
    func shouldGenerateNext(task: TaskItem) -> Bool {
        guard task.recurrence != .none else { return false }
        guard task.isCompleted else { return false }
        return true
    }

    /// 为所有已完成的重复任务创建下一次出现
    func createRecurringTasks(for task: TaskItem) async -> TaskItem? {
        guard shouldGenerateNext(task: task) else { return nil }
        return generateNextOccurrence(task: task)
    }

    /// 获取即将到期的重复任务
    func getUpcomingRecurringTasks(from tasks: [TaskItem], withinDays: Int = 7) -> [TaskItem] {
        let calendar = Calendar.current
        let now = Date()
        let futureDate = calendar.date(byAdding: .day, value: withinDays, to: now) ?? now

        return tasks.filter { task in
            guard task.recurrence != .none else { return false }
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= now && dueDate <= futureDate && !task.isCompleted
        }
    }

    /// 批量处理重复任务生成
    func processAllRecurringTasks(tasks: [TaskItem]) -> [TaskItem] {
        var newTasks: [TaskItem] = []
        for task in tasks where shouldGenerateNext(task: task) {
            if let next = generateNextOccurrence(task: task) {
                newTasks.append(next)
            }
        }
        return newTasks
    }

    /// 计算下一次出现日期（仅返回日期，不创建任务）
    func calculateNextDueDate(from date: Date, recurrence: RecurrenceRule) -> Date? {
        guard recurrence != .none else { return nil }

        let calendar = Calendar.current
        switch recurrence {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        case .none:
            return nil
        }
    }

    /// 获取重复规则的中文描述
    func recurrenceDescription(_ recurrence: RecurrenceRule) -> String {
        recurrence.displayName
    }
}
