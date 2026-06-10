// MARK: - Imports
import Foundation
import SwiftUI

// MARK: - Supporting Types

/// 任务标签
struct TaskTag: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var color: TagColor

    init(id: UUID = UUID(), name: String, color: TagColor) {
        self.id = id
        self.name = name
        self.color = color
    }
}

/// 标签颜色（使用可编码的枚举包装）
enum TagColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, pink, gray

    var swiftUIColor: Color {
        switch self {
        case .red:    return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green:  return .green
        case .blue:   return .blue
        case .purple: return .purple
        case .pink:   return .pink
        case .gray:   return .gray
        }
    }
}

// MARK: - TaskStore

/// 核心任务状态管理器
@Observable
@MainActor
final class TaskStore {

    // MARK: - Shared Instance

    static let shared = TaskStore()

    // MARK: - Published Properties

    var tasks: [TaskItem] = []
    var tags: [TaskTag] = []
    var selectedTaskId: UUID?
    var searchText: String = ""
    var filterStatus: TaskStatus?
    var filterPriority: TaskPriority?
    var sortOption: SortOption = .dueDate

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private var saveTask: Task<Void, Never>?
    private let persistenceQueue = DispatchQueue(label: "com.chengfengplan.persistence", qos: .utility)

    private var tasksURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ChengFengPlan_Tasks.json")
    }

    private var backupDirectoryURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backups", isDirectory: true)
    }

    // MARK: - Initialization

    private init() {
        Task { @MainActor in
            await loadTasks()
            createBackupDirectoryIfNeeded()
        }
    }

    // MARK: - Task CRUD

    /// 添加任务
    func addTask(_ task: TaskItem) {
        guard !task.title.isEmpty else { return }
        modifyTasks {
            tasks.append(task)
        }
    }

    /// 更新任务
    func updateTask(_ task: TaskItem) {
        guard !task.title.isEmpty else { return }
        modifyTasks {
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index] = task
                tasks[index].updatedAt = Date()
            }
        }
    }

    /// 删除任务（使用 BFS 避免递归栈溢出）
    func deleteTask(id: UUID) {
        modifyTasks {
            var idsToDelete = Set<UUID>()
            var queue: [UUID] = [id]

            while !queue.isEmpty {
                let currentId = queue.removeFirst()
                idsToDelete.insert(currentId)

                if let task = tasks.first(where: { $0.id == currentId }) {
                    queue.append(contentsOf: task.subTaskIds)
                }
            }

            tasks.removeAll { idsToDelete.contains($0.id) }

            // 清理父任务中的子任务引用
            for index in tasks.indices {
                tasks[index].subTaskIds.removeAll { idsToDelete.contains($0) }
                if tasks[index].parentTaskId == id {
                    tasks[index].parentTaskId = nil
                }
            }
        }
    }

    /// 切换任务完成状态
    func toggleTaskCompletion(id: UUID) {
        modifyTasks {
            if let index = tasks.firstIndex(where: { $0.id == id }) {
                if tasks[index].status == .completed {
                    tasks[index].markAsPending()
                } else {
                    tasks[index].markAsCompleted()
                }
            }
        }
    }

    // MARK: - Tag Management

    /// 添加标签
    func addTag(_ tag: TaskTag) {
        modifyTasks {
            tags.append(tag)
        }
    }

    /// 删除标签
    func deleteTag(id: UUID) {
        modifyTasks {
            tags.removeAll { $0.id == id }
            for index in tasks.indices {
                tasks[index].removeTag(id)
            }
        }
    }

    // MARK: - Query Methods

    /// 获取指定日期的任务
    func getTasksForDate(_ date: Date) -> [TaskItem] {
        let calendar = Calendar.current
        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
        }
    }

    /// 获取逾期任务
    func getOverdueTasks() -> [TaskItem] {
        let now = Date()
        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < now && !task.isCompleted
        }
    }

    /// 获取指定标签的任务
    func getTasksForTag(id: UUID) -> [TaskItem] {
        tasks.filter { $0.tags.contains(id) }
    }

    /// 搜索任务
    func searchTasks(query: String) -> [TaskItem] {
        let lowercasedQuery = query.lowercased()
        return tasks.filter { task in
            task.title.lowercased().contains(lowercasedQuery) ||
            task.description.lowercased().contains(lowercasedQuery)
        }
    }

    /// 获取过滤并排序后的任务
    func filteredAndSortedTasks() -> [TaskItem] {
        var result = tasks

        if let status = filterStatus {
            result = result.filter { $0.status == status }
        }

        if let priority = filterPriority {
            result = result.filter { $0.priority == priority }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.description.lowercased().contains(query)
            }
        }

        switch sortOption {
        case .dueDate:
            result.sort {
                guard let d1 = $0.dueDate else { return false }
                guard let d2 = $1.dueDate else { return true }
                return d1 < d2
            }
        case .priority:
            result.sort { $0.priority > $1.priority }
        case .createdAt:
            result.sort { $0.createdAt > $1.createdAt }
        case .custom:
            break
        case .title:
            result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        }

        return result
    }

    // MARK: - Persistence

    /// 保存任务到 JSON 文件（原子写入）
    nonisolated func saveTasks() async {
        let data = await MainActor.run {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let container = TaskStoreData(tasks: self.tasks, tags: self.tags)
            return try? encoder.encode(container)
        }

        guard let encoded = data else { return }

        let url = await MainActor.run { self.tasksURL }
        let tempURL = url.deletingLastPathComponent()
            .appendingPathComponent("ChengFengPlan_Tasks_temp.json")

        await withCheckedContinuation { continuation in
            persistenceQueue.async {
                do {
                    try encoded.write(to: tempURL, options: .atomic)
                    _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
                } catch {
                    print("[TaskStore] Save error: \(error.localizedDescription)")
                }
                continuation.resume()
            }
        }
    }

    /// 从 JSON 文件加载任务
    func loadTasks() async {
        let url = tasksURL
        let (loadedTasks, loadedTags): ([TaskItem], [TaskTag]) = await withCheckedContinuation { continuation in
            persistenceQueue.async {
                do {
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let container = try decoder.decode(TaskStoreData.self, from: data)
                    continuation.resume(returning: (container.tasks, container.tags))
                } catch {
                    print("[TaskStore] Load error: \(error.localizedDescription)")
                    continuation.resume(returning: ([], []))
                }
            }
        }
        self.tasks = loadedTasks
        self.tags = loadedTags
    }

    /// 自动备份恢复
    func restoreFromBackupIfNeeded() async {
        guard !FileManager.default.fileExists(atPath: tasksURL.path) else { return }

        let backups = await getBackupFiles()
        guard let latestBackup = backups.first else { return }

        do {
            let data = try Data(contentsOf: latestBackup)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let container = try decoder.decode(TaskStoreData.self, from: data)
            tasks = container.tasks
            tags = container.tags
            await saveTasks()
        } catch {
            print("[TaskStore] Restore error: \(error.localizedDescription)")
        }
    }

    /// 获取备份文件列表（按修改时间排序）
    nonisolated func getBackupFiles() async -> [URL] {
        let backupDir = await MainActor.run { backupDirectoryURL }
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: backupDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )
            return files.sorted {
                let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                return d1 > d2
            }
        } catch {
            return []
        }
    }

    // MARK: - Private Helpers

    /// 线程安全包装器：所有可变操作在此闭包中执行，完成后自动触发保存
    private func modifyTasks(_ operation: () -> Void) {
        operation()
        scheduleSave()
    }

    /// 延迟保存（防抖）
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            await saveTasks()
        }
    }

    private func createBackupDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: backupDirectoryURL.path) {
            try? fileManager.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true)
        }
    }
}

// MARK: - Persistence Container

/// 用于 JSON 编码/解码的数据容器
private struct TaskStoreData: Codable {
    var tasks: [TaskItem]
    var tags: [TaskTag]
}
