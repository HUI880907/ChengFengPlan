// MARK: - BackupManager.swift
// 乘风计划 - 自动备份管理器

import Foundation

// MARK: - BackupFrequency

enum BackupFrequency: String, Codable, CaseIterable, Identifiable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "每天"
        case .weekly: return "每周"
        case .monthly: return "每月"
        }
    }
}

// MARK: - BackupSettings

struct BackupSettings: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var frequency: BackupFrequency
    var backupTime: Date
    var retentionCount: Int
    var lastBackupDate: Date?

    static let `default` = BackupSettings(
        isEnabled: false,
        frequency: .daily,
        backupTime: Calendar.current.date(from: DateComponents(hour: 2, minute: 0)) ?? Date(),
        retentionCount: 7,
        lastBackupDate: nil
    )
}

// MARK: - BackupRecord

struct BackupRecord: Identifiable {
    let id = UUID()
    let url: URL
    let date: Date
    let size: Int64

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - BackupManager

/// 自动备份管理器
@MainActor
final class BackupManager {

    // MARK: - Shared Instance

    static let shared = BackupManager()

    // MARK: - Published Properties

    var settings: BackupSettings {
        didSet { saveSettings() }
    }

    var isBackingUp: Bool = false
    var lastBackupResult: Result<Date, Error>?

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private let settingsKey = "backup_settings_v3"
    private var backupTimer: Timer?
    private let backupQueue = DispatchQueue(label: "com.chengfengplan.backup", qos: .background)

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var backupDirectoryURL: URL {
        documentsURL.appendingPathComponent("Backups", isDirectory: true)
    }

    private var tasksURL: URL {
        documentsURL.appendingPathComponent("ChengFengPlan_Tasks.json")
    }

    // MARK: - Initialization

    private init() {
        self.settings = BackupManager.loadSettings()
        createBackupDirectoryIfNeeded()
        scheduleNextBackup()
    }

    // MARK: - Settings Persistence

    private static func loadSettings() -> BackupSettings {
        guard let data = UserDefaults.standard.data(forKey: "backup_settings_v3"),
              let settings = try? JSONDecoder().decode(BackupSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    // MARK: - Backup Operations

    /// 执行立即备份
    func performBackup() async throws -> URL {
        isBackingUp = true
        defer { isBackingUp = false }

        return try await Task.detached(priority: .background) { [weak self] in
            guard let self else {
                throw FileSyncError.exportFailed("BackupManager 已释放")
            }

            await self.createBackupDirectoryIfNeeded()

            let timestamp = await self.dateString()
            let backupFilename = "ChengFengPlan_Backup_\(timestamp).json"
            let backupURL = await self.backupDirectoryURL.appendingPathComponent(backupFilename)

            // 读取当前任务数据
            let taskStore = await TaskStore.shared
            let tasks = await taskStore.tasks
            let tags = await taskStore.tags
            let container = BackupContainer(
                tasks: tasks,
                tags: tags,
                backupDate: Date(),
                appVersion: await self.appVersion()
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(container)
            try data.write(to: backupURL, options: .atomic)

            await MainActor.run {
                self.settings.lastBackupDate = Date()
            }

            // 清理旧备份
            await self.cleanupOldBackups()

            return backupURL
        }.value
    }

    /// 获取所有备份记录
    func getBackupRecords() -> [BackupRecord] {
        do {
            let files = try fileManager.contentsOfDirectory(
                at: backupDirectoryURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
            return files
                .filter { $0.lastPathComponent.hasPrefix("ChengFengPlan_Backup_") && $0.pathExtension == "json" }
                .compactMap { url -> BackupRecord? in
                    guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                          let date = values.contentModificationDate,
                          let size = values.fileSize else { return nil }
                    return BackupRecord(url: url, date: date, size: Int64(size))
                }
                .sorted { $0.date > $1.date }
        } catch {
            return []
        }
    }

    /// 从备份恢复
    func restoreFromBackup(url: URL) async throws -> ImportResult {
        try await Task.detached(priority: .background) {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let container = try decoder.decode(BackupContainer.self, from: data)
            return ImportResult(
                tasks: container.tasks,
                tags: container.tags,
                taskCount: container.tasks.count,
                tagCount: container.tags.count
            )
        }.value
    }

    /// 删除指定备份
    func deleteBackup(url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    /// 计算下次备份时间
    func nextBackupDate() -> Date? {
        guard settings.isEnabled else { return nil }
        guard let lastDate = settings.lastBackupDate else {
            return nextScheduledDate(from: Date())
        }
        return nextScheduledDate(from: lastDate)
    }

    // MARK: - Private Helpers

    private func createBackupDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: backupDirectoryURL.path) {
            try? fileManager.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func cleanupOldBackups() {
        let records = getBackupRecords()
        guard records.count > settings.retentionCount else { return }

        let recordsToDelete = records.suffix(from: settings.retentionCount)
        for record in recordsToDelete {
            try? fileManager.removeItem(at: record.url)
        }
    }

    private func scheduleNextBackup() {
        backupTimer?.invalidate()
        guard settings.isEnabled else { return }

        guard let nextDate = nextBackupDate() else { return }
        let interval = nextDate.timeIntervalSinceNow
        guard interval > 0 else {
            // 如果已经过期，立即执行
            Task { try? await performBackup() }
            return
        }

        backupTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                try? await self.performBackup()
                self.scheduleNextBackup()
            }
        }
    }

    private func nextScheduledDate(from date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute], from: settings.backupTime)

        var nextDate: Date?
        switch settings.frequency {
        case .daily:
            var targetComponents = calendar.dateComponents([.year, .month, .day], from: date)
            targetComponents.hour = components.hour
            targetComponents.minute = components.minute
            if let target = calendar.date(from: targetComponents), target <= date {
                nextDate = calendar.date(byAdding: .day, value: 1, to: target)
            } else {
                nextDate = calendar.date(from: targetComponents)
            }
        case .weekly:
            var targetComponents = calendar.dateComponents([.year, .month, .day], from: date)
            targetComponents.hour = components.hour
            targetComponents.minute = components.minute
            if let target = calendar.date(from: targetComponents), target <= date {
                nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: target)
            } else {
                nextDate = calendar.date(from: targetComponents)
            }
        case .monthly:
            var targetComponents = calendar.dateComponents([.year, .month, .day], from: date)
            targetComponents.hour = components.hour
            targetComponents.minute = components.minute
            if let target = calendar.date(from: targetComponents), target <= date {
                nextDate = calendar.date(byAdding: .month, value: 1, to: target)
            } else {
                nextDate = calendar.date(from: targetComponents)
            }
        }
        return nextDate ?? date.addingTimeInterval(86400)
    }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    private func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0"
    }
}

// MARK: - Backup Container

private struct BackupContainer: Codable {
    let tasks: [TaskItem]
    let tags: [TaskTag]
    let backupDate: Date
    let appVersion: String
}
