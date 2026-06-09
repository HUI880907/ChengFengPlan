// MARK: - Imports
import Foundation

// MARK: - DailyBriefingService

/// 每日智能简报服务
final class DailyBriefingService {

    // MARK: - Shared Instance

    static let shared = DailyBriefingService()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 生成指定日期的简报
    func generateBriefing(for date: Date, tasks: [TaskItem]) -> DailyBriefing {
        let todayTasks = getTodayTasks(for: date, tasks: tasks)
        let overdueTasks = getOverdueTasks(tasks: tasks)
        let completedToday = getCompletedToday(for: date, tasks: tasks)
        let completionRate = todayTasks.isEmpty ? 0.0 : Double(completedToday.count) / Double(todayTasks.count)

        return DailyBriefing(
            date: date,
            totalTasks: todayTasks.count,
            completedTasks: completedToday.count,
            overdueTasks: overdueTasks.count,
            completionRate: completionRate,
            highPriorityTasks: todayTasks.filter { $0.priority == .high || $0.priority == .urgent },
            upcomingTasks: todayTasks.filter { !$0.isCompleted }.sorted {
                ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
        )
    }

    /// 获取指定日期的任务
    func getTodayTasks(for date: Date, tasks: [TaskItem]) -> [TaskItem] {
        let calendar = Calendar.current
        return tasks.filter { task in
            // 已完成任务：按完成日期判断
            if task.isCompleted, let completedDate = task.completedAt {
                return calendar.isDate(completedDate, inSameDayAs: date)
            }
            // 未完成任务：按截止日期判断
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
        }
    }

    /// 获取所有逾期任务
    func getOverdueTasks(tasks: [TaskItem]) -> [TaskItem] {
        let now = Date()
        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < now && !task.isCompleted
        }
    }

    /// 获取今日已完成的任务
    func getCompletedToday(for date: Date, tasks: [TaskItem]) -> [TaskItem] {
        let calendar = Calendar.current
        return tasks.filter { task in
            guard task.isCompleted else { return false }
            return calendar.isDate(task.updatedAt, inSameDayAs: date)
        }
    }

    /// 生成简报文本内容
    func getBriefingContent(for date: Date, tasks: [TaskItem]) -> String {
        let briefing = generateBriefing(for: date, tasks: tasks)
        let formatter = DateFormatterCache.shared.mediumDateFormatter
        let dateString = formatter.string(from: date)

        var content = "📋 \(dateString) 任务简报\n"
        content += "━━━━━━━━━━━━━━━━━━━━\n\n"

        content += "📊 今日统计\n"
        content += "   总任务: \(briefing.totalTasks)\n"
        content += "   已完成: \(briefing.completedTasks)\n"
        content += "   逾期任务: \(briefing.overdueTasks)\n"
        content += "   完成率: \(Int(briefing.completionRate * 100))%\n\n"

        if !briefing.highPriorityTasks.isEmpty {
            content += "🔥 高优先级任务\n"
            for task in briefing.highPriorityTasks {
                let status = task.isCompleted ? "✅" : "⬜"
                content += "   \(status) \(task.title)\n"
            }
            content += "\n"
        }

        if !briefing.upcomingTasks.isEmpty {
            content += "📅 待办事项\n"
            for task in briefing.upcomingTasks.prefix(5) {
                let timeString = task.dueDate != nil
                    ? DateFormatterCache.shared.shortTimeFormatter.string(from: task.dueDate!)
                    : "无时间"
                content += "   ⬜ \(task.title) (\(timeString))\n"
            }
            content += "\n"
        }

        if briefing.overdueTasks > 0 {
            content += "⚠️ 您有 \(briefing.overdueTasks) 个逾期任务，请尽快处理！\n"
        }

        return content
    }
}

// MARK: - DailyBriefing

/// 每日简报数据模型
struct DailyBriefing: Identifiable {
    let id = UUID()
    let date: Date
    let totalTasks: Int
    let completedTasks: Int
    let overdueTasks: Int
    let completionRate: Double
    let highPriorityTasks: [TaskItem]
    let upcomingTasks: [TaskItem]
}


