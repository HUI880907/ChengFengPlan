// MARK: - Imports
import Foundation
import UserNotifications

// MARK: - NotificationScheduler

/// 本地通知调度服务
final class NotificationScheduler {

    // MARK: - Shared Instance

    static let shared = NotificationScheduler()

    // MARK: - Private Properties

    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - Initialization

    private init() {}

    // MARK: - Authorization

    /// 请求通知权限
    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .badge, .sound]
            let granted = try await notificationCenter.requestAuthorization(options: options)
            return granted
        } catch {
            print("[NotificationScheduler] Authorization error: \(error.localizedDescription)")
            return false
        }
    }

    /// 检查当前通知权限状态
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Task Notifications

    /// 为任务调度通知
    func scheduleNotification(for task: TaskItem) async {
        guard let reminderDate = task.reminderDate else { return }
        guard reminderDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "乘风计划"
        content.body = "任务提醒: \(task.title)"
        content.sound = .default
        content.badge = 1
        content.userInfo = ["taskId": task.id.uuidString]

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = notificationIdentifier(for: task.id)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
        } catch {
            print("[NotificationScheduler] Schedule error: \(error.localizedDescription)")
        }
    }

    /// 取消指定任务的通知
    func cancelNotification(taskId: UUID) {
        let identifier = notificationIdentifier(for: taskId)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// 批量调度任务通知
    func scheduleNotifications(for tasks: [TaskItem]) async {
        for task in tasks {
            await scheduleNotification(for: task)
        }
    }

    // MARK: - Daily Reminder

    /// 设置每日提醒
    func scheduleDailyReminder(time: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "乘风计划"
        content.body = "查看今日任务，开启高效的一天！"
        content.sound = .default

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: "daily_reminder",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("[NotificationScheduler] Daily reminder error: \(error.localizedDescription)")
        }
    }

    /// 取消每日提醒
    func cancelDailyReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
    }

    // MARK: - Bulk Operations

    /// 取消所有通知
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }

    /// 获取所有待发送的通知
    func getPendingNotifications() async -> [UNNotificationRequest] {
        await notificationCenter.pendingNotificationRequests()
    }

    /// 获取已送达的通知
    func getDeliveredNotifications() async -> [UNNotification] {
        await notificationCenter.deliveredNotifications()
    }

    // MARK: - Private Helpers

    private func notificationIdentifier(for taskId: UUID) -> String {
        "task_\(taskId.uuidString)"
    }
}
