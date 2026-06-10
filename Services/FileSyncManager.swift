// MARK: - Imports
import Foundation
#if os(macOS)
import ZIPFoundation
#endif

// MARK: - FileSyncError

enum FileSyncError: LocalizedError {
    case exportFailed(String)
    case importFailed(String)
    case invalidFileFormat
    case fileNotAccessible
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .exportFailed(let msg):
            return "导出失败: \(msg)"
        case .importFailed(let msg):
            return "导入失败: \(msg)"
        case .invalidFileFormat:
            return "文件格式无效，请确保选择正确的 JSON 导出文件"
        case .fileNotAccessible:
            return "无法访问文件，请检查文件权限"
        case .encodingFailed:
            return "数据编码失败"
        case .decodingFailed:
            return "数据解码失败，文件可能已损坏"
        }
    }
}

// MARK: - ImportResult

struct ImportResult {
    let tasks: [TaskItem]
    let tags: [TaskTag]
    let taskCount: Int
    let tagCount: Int
}

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

    /// 导出文件存放目录（iOS 文件 App 可见）
    private var exportsDirectoryURL: URL {
        let url = documentsURL.appendingPathComponent("乘风计划", isDirectory: true)
        // 设置目录为共享可见，使文件 App 可以访问
        return url
    }

    // MARK: - Initialization

    private init() {
        createExportsDirectoryIfNeeded()
    }

    // MARK: - Export

    /// 导出任务和标签到指定 URL
    /// - Returns: 导出的文件 URL（位于 App Documents/Exports 目录下）
    func exportToURL(tasks: [TaskItem], tags: [TaskTag]) async throws -> URL {
        await MainActor.run { isExporting = true }
        defer { Task { @MainActor in isExporting = false } }

        let container = ExportContainer(tasks: tasks, tags: tags, exportDate: Date())

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(container)

            let filename = "乘风计划_\(dateString()).json"
            let url = exportsDirectoryURL.appendingPathComponent(filename)

            // 确保目录存在
            createExportsDirectoryIfNeeded()

            // 原子写入
            try data.write(to: url, options: .atomic)

            // 设置文件属性，使其在 iOS 文件 App 中可见
            try? fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )

            await MainActor.run { lastBackupURL = url }
            return url
        } catch let error as FileSyncError {
            throw error
        } catch {
            throw FileSyncError.exportFailed(error.localizedDescription)
        }
    }

    /// 从 URL 导入数据
    /// - Parameter url: 用户选择的 JSON 文件 URL（可能是安全沙盒临时 URL）
    /// - Returns: 导入结果，包含任务和标签列表
    func importFromURL(_ url: URL) async throws -> ImportResult {
        await MainActor.run { isImporting = true }
        defer { Task { @MainActor in isImporting = false } }

        // 确保可以访问文件（处理安全沙盒临时文件）
        let accessibleURL: URL
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        if didStartAccessing {
            accessibleURL = url
        } else {
            // 尝试复制到临时目录
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("json")
            do {
                try FileManager.default.copyItem(at: url, to: tempURL)
                accessibleURL = tempURL
            } catch {
                throw FileSyncError.fileNotAccessible
            }
        }

        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: accessibleURL)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let container = try decoder.decode(ExportContainer.self, from: data)

            // 验证数据
            guard !container.tasks.isEmpty || !container.tags.isEmpty else {
                throw FileSyncError.invalidFileFormat
            }

            // 清理临时文件
            if accessibleURL != url {
                try? fileManager.removeItem(at: accessibleURL)
            }

            return ImportResult(
                tasks: container.tasks,
                tags: container.tags,
                taskCount: container.tasks.count,
                tagCount: container.tags.count
            )
        } catch let error as FileSyncError {
            throw error
        } catch DecodingError.dataCorrupted(let context) {
            throw FileSyncError.decodingFailed
        } catch DecodingError.keyNotFound(_, let context) {
            throw FileSyncError.invalidFileFormat
        } catch DecodingError.typeMismatch(_, let context) {
            throw FileSyncError.invalidFileFormat
        } catch {
            throw FileSyncError.importFailed(error.localizedDescription)
        }
    }

    // MARK: - Backup Management

    /// 获取所有备份文件列表
    func getBackupFiles() -> [URL] {
        do {
            let files = try fileManager.contentsOfDirectory(
                at: exportsDirectoryURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )
            return files
                .filter { $0.lastPathComponent.hasPrefix("乘风计划_") && $0.pathExtension == "json" }
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
    func restoreFromBackup(url: URL) async throws -> ImportResult {
        try await importFromURL(url)
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

    private func createExportsDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: exportsDirectoryURL.path) {
            try? fileManager.createDirectory(
                at: exportsDirectoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    /// 建议的导出文件名（供 UI 使用）
    var suggestedExportFilename: String {
        return "乘风计划_\(dateString()).json"
    }

    /// 生成 yyyyMMdd_HHmmss 格式的时间字符串
    func dateString() -> String {
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
