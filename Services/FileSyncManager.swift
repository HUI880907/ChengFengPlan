// MARK: - Imports
import Foundation
#if os(macOS)
import ZIPFoundation
#endif

// MARK: - FileSyncManager

/// 文件同步与备份管理器
@MainActor
@Observable
final class FileSyncManager {

    // MARK: - Shared Instance

    static let shared = FileSyncManager()

    // MARK: - Published Properties

    var isExporting: Bool = false
    var isImporting: Bool = false
    var lastError: String?
    var lastBackupURL: URL?

    // MARK: - Private Properties

    private let fileManager = FileManager.default

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Export

    /// 导出任务和标签到指定 URL
    func exportToURL(tasks: [TaskItem], tags: [TaskTag]) async -> URL? {
        await MainActor.run { isExporting = true }
        defer { Task { @MainActor in isExporting = false } }

        let container = ExportContainer(tasks: tasks, tags: tags, exportDate: Date())

        do {
            let data = try JSONEncoder().encode(container)
            let filename = "ChengFengPlan_Export_\(dateString()).json"
            let url = documentsURL.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            await MainActor.run { lastBackupURL = url }
            return url
        } catch {
            await MainActor.run { lastError = "导出失败: \(error.localizedDescription)" }
            return nil
        }
    }

    /// 从 URL 导入数据
    func importFromURL(_ url: URL) async -> (tasks: [TaskItem], tags: [TaskTag])? {
        await MainActor.run { isImporting = true }
        defer { Task { @MainActor in isImporting = false } }

        do {
            let data = try Data(contentsOf: url)
            let container = try JSONDecoder().decode(ExportContainer.self, from: data)
            return (container.tasks, container.tags)
        } catch {
            await MainActor.run { lastError = "导入失败: \(error.localizedDescription)" }
            return nil
        }
    }

    // MARK: - Backup Management

    /// 获取所有备份文件列表
    func getBackupFiles() -> [URL] {
        do {
            let files = try fileManager.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )
            return files
                .filter { $0.lastPathComponent.hasPrefix("ChengFengPlan_Export_") }
                .sorted {
                    let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                    let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                    return d1 > d2
                }
        } catch {
            return []
        }
    }

    /// 从备份文件恢复
    func restoreFromBackup(url: URL) async -> (tasks: [TaskItem], tags: [TaskTag])? {
        await importFromURL(url)
    }

    // MARK: - ZIP Archive

    /// 创建 ZIP 压缩包
    func createZipArchive(source: URL, destination: URL) -> Bool {
        #if os(macOS)
        do {
            try fileManager.zipItem(at: source, to: destination)
            return true
        } catch {
            lastError = "压缩失败: \(error.localizedDescription)"
            return false
        }
        #else
        // iOS 使用自定义 ZIP 实现或第三方库
        lastError = "iOS 平台暂不支持原生 ZIP 压缩，请使用第三方库如 ZIPFoundation"
        return false
        #endif
    }

    /// 解压 ZIP 压缩包
    func unzipArchive(source: URL, destination: URL) -> Bool {
        #if os(macOS)
        do {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            try fileManager.unzipItem(at: source, to: destination)
            return true
        } catch {
            lastError = "解压失败: \(error.localizedDescription)"
            return false
        }
        #else
        lastError = "iOS 平台暂不支持原生 ZIP 解压，请使用第三方库如 ZIPFoundation"
        return false
        #endif
    }

    // MARK: - Private Helpers

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}

// MARK: - Export Container

/// 导出数据容器
private struct ExportContainer: Codable {
    let tasks: [TaskItem]
    let tags: [TaskTag]
    let exportDate: Date
    let version: String

    init(tasks: [TaskItem], tags: [TaskTag], exportDate: Date, version: String = "2.0") {
        self.tasks = tasks
        self.tags = tags
        self.exportDate = exportDate
        self.version = version
    }
}
