import Foundation
import Combine

// MARK: - TrashEntry

struct TrashEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let task: TaskItem
    let deletedAt: Date
    let expiresAt: Date

    init(
        id: UUID = UUID(),
        task: TaskItem,
        deletedAt: Date = Date(),
        expiresAt: Date
    ) {
        self.id = id
        self.task = task
        self.deletedAt = deletedAt
        self.expiresAt = expiresAt
    }

    var daysUntilExpiration: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: expiresAt)
        )
        return components.day ?? 0
    }

    var isExpired: Bool {
        Date() >= expiresAt
    }
}

// MARK: - TrashManager

@MainActor
@Observable
final class TrashManager {

    // MARK: - Singleton

    static let shared = TrashManager()

    // MARK: - Properties

    var entries: [TrashEntry] = []

    private nonisolated(unsafe) var cleanupTimer: Timer?
    private let trashRetentionDays: Int = 30
    private let trashKey = "com.chengfengplan.trash"

    var entryCount: Int {
        entries.count
    }

    var isEmpty: Bool {
        entries.isEmpty
    }

    // MARK: - Initialization

    private init() {
        loadTrash()
        startCleanupTimer()
    }

    deinit {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }

    // MARK: - Persistence

    private func loadTrash() {
        guard let data = UserDefaults.standard.data(forKey: trashKey) else { return }
        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode([TrashEntry].self, from: data)
            entries = decoded
        } catch {
            print("[TrashManager] Failed to load trash: \(error)")
        }
    }

    private func saveTrash() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(entries)
            UserDefaults.standard.set(data, forKey: trashKey)
        } catch {
            print("[TrashManager] Failed to save trash: \(error)")
        }
    }

    // MARK: - Timer Management

    private func startCleanupTimer() {
        cleanupTimer?.invalidate()
        cleanupTimer = Timer.scheduledTimer(
            withTimeInterval: 3600, // 每小时检查一次
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.cleanExpired()
            }
        }
    }

    private func stopCleanupTimer() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }

    // MARK: - Public Methods

    /// 将任务移入垃圾箱
    func moveToTrash(_ task: TaskItem) {
        let calendar = Calendar.current
        guard let expirationDate = calendar.date(byAdding: .day, value: trashRetentionDays, to: Date()) else {
            return
        }

        let entry = TrashEntry(
            task: task,
            deletedAt: Date(),
            expiresAt: expirationDate
        )

        entries.append(entry)
        saveTrash()
    }

    /// 从垃圾箱恢复任务
    func restoreTask(id: UUID) -> TaskItem? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            print("[TrashManager] Task not found in trash: \(id)")
            return nil
        }

        let entry = entries.remove(at: index)
        saveTrash()
        return entry.task
    }

    /// 永久删除指定任务
    func permanentlyDelete(id: UUID) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            print("[TrashManager] Task not found in trash: \(id)")
            return false
        }

        entries.remove(at: index)
        saveTrash()
        return true
    }

    /// 清理所有已过期的条目
    func cleanExpired() {
        let beforeCount = entries.count
        entries.removeAll { $0.isExpired }
        let afterCount = entries.count

        if beforeCount != afterCount {
            print("[TrashManager] Cleaned \(beforeCount - afterCount) expired entries")
            saveTrash()
        }
    }

    /// 清空垃圾箱（永久删除所有）
    func emptyTrash() {
        let count = entries.count
        entries.removeAll()
        saveTrash()
        print("[TrashManager] Emptied trash, deleted \(count) entries")
    }

    /// 获取指定任务的垃圾箱条目
    func entry(for taskId: UUID) -> TrashEntry? {
        entries.first { $0.task.id == taskId }
    }

    /// 检查任务是否在垃圾箱中
    func contains(taskId: UUID) -> Bool {
        entries.contains { $0.task.id == taskId }
    }

    /// 获取即将过期的条目（7天内）
    func getExpiringSoonEntries(days: Int = 7) -> [TrashEntry] {
        let calendar = Calendar.current
        let threshold = calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return entries.filter { $0.expiresAt <= threshold && !$0.isExpired }
    }
}
