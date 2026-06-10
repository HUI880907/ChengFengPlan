// MARK: - SettingsView.swift
// 乘风计划 - 设置视图

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Toast Modifier

struct ToastModifier: ViewModifier {
    let message: String
    let isError: Bool
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            Text(message)
                                .font(.subheadline)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(isError ? Color.red.opacity(0.9) : Color.green.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.easeInOut(duration: 0.3), value: isPresented)
                }
            }
    }
}

extension View {
    func toast(message: String, isError: Bool = false, isPresented: Binding<Bool>) -> some View {
        modifier(ToastModifier(message: message, isError: isError, isPresented: isPresented))
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(TaskStore.self) private var taskStore
    @State private var aiProvider: AIProvider = .zhipu
    @State private var apiKey = ""
    @State private var apiBaseURL = ""
    @State private var selectedModel = ""
    @State private var notificationsEnabled = false
    @State private var notificationPermissionStatus: String = "未请求"
    @State private var reminderTime = Date()
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @State private var defaultPriority: TaskPriority = .medium
    @State private var defaultSort: SortOption = .dueDate
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var showingPrivacyPolicy = false
    @State private var showingClearDataAlert = false
    @State private var showingResetStatsAlert = false
    @State private var showingClearCacheAlert = false
    @State private var appVersion = "3.0.0"
    @State private var buildNumber = "1"

    /// 根据 AI 提供商返回对应的模型列表
    private var availableModels: [String] {
        switch aiProvider {
        case .zhipu:
            return ["glm-4", "glm-4-plus", "glm-4-flash", "glm-4-long"]
        case .tongyi:
            return ["qwen-max", "qwen-plus", "qwen-turbo", "qwen-long"]
        case .wenxin:
            return ["ernie-4.0", "ernie-3.5", "ernie-speed", "ernie-lite"]
        case .spark:
            return ["spark-v4.0", "spark-v3.5", "spark-v3.0", "spark-lite"]
        case .moonshot:
            return ["moonshot-v1-128k", "moonshot-v1-32k", "moonshot-v1-8k"]
        case .minimax:
            return ["abab6.5s", "abab6", "abab5.5"]
        case .zeroOne:
            return ["yi-large", "yi-medium", "yi-spark", "yi-lightning"]
        case .custom:
            return ["custom"]
        }
    }

    /// AI提供商API Key获取链接
    private var providerAPIKeyURL: String {
        switch aiProvider {
        case .zhipu:
            return "https://open.bigmodel.cn/usercenter/apikeys"
        case .tongyi:
            return "https://dashscope.console.aliyun.com/apiKey"
        case .wenxin:
            return "https://console.bce.baidu.com/qianfan/ais/console/applicationConsole/application"
        case .spark:
            return "https://xinghuo.xfyun.cn/sparkapi"
        case .moonshot:
            return "https://platform.moonshot.cn/console/api-keys"
        case .minimax:
            return "https://platform.minimaxi.com/account/apikey"
        case .zeroOne:
            return "https://platform.01.ai/apikeys"
        case .custom:
            return ""
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: AI 设置
                Section {
                    Picker("提供商", selection: $aiProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }

                    if aiProvider != .custom {
                        if let url = URL(string: providerAPIKeyURL) {
                            Link(destination: url) {
                                HStack {
                                    Label("获取 API Key", systemImage: "link")
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    SecureField("API Key", text: $apiKey)
                        .onChange(of: apiKey) { _, newValue in
                            SecureStore.shared.saveString(key: "ai_api_key_\(aiProvider.rawValue)", value: newValue)
                            AIManager.shared.setAPIKey(newValue, for: aiProvider)
                        }

                    if aiProvider == .custom {
                        HStack {
                            Text("API 地址")
                            Spacer()
                            TextField("https://...", text: $apiBaseURL)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                        }
                    }

                    Picker("模型", selection: $selectedModel) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .onChange(of: aiProvider) { _, _ in
                        selectedModel = availableModels.first ?? ""
                        apiKey = SecureStore.shared.loadString(key: "ai_api_key_\(aiProvider.rawValue)") ?? ""
                        apiBaseURL = aiProvider.defaultBaseURL
                    }

                    LabeledContent("状态", value: apiKey.isEmpty ? "未配置" : "已配置")
                        .foregroundStyle(apiKey.isEmpty ? Color.secondary : Color.green)
                } header: {
                    Text("AI 设置")
                } footer: {
                    Text("选择 AI 提供商并配置 API Key 以启用 AI 助手功能。API Key 安全存储在设备钥匙串中。")
                }

                // MARK: 通知设置
                Section {
                    Toggle("启用通知", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, isOn in
                            Task {
                                if isOn {
                                    let granted = await NotificationScheduler.shared.requestAuthorization()
                                    await MainActor.run {
                                        if !granted {
                                            notificationsEnabled = false
                                            notificationPermissionStatus = "被拒绝"
                                        } else {
                                            notificationPermissionStatus = "已授权"
                                        }
                                    }
                                    if granted {
                                        await NotificationScheduler.shared.scheduleDailyReminder(time: reminderTime)
                                    }
                                } else {
                                    NotificationScheduler.shared.cancelDailyReminder()
                                    notificationPermissionStatus = "已关闭"
                                }
                            }
                        }

                    LabeledContent("通知权限", value: notificationPermissionStatus)

                    if notificationsEnabled {
                        DatePicker("每日提醒时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: reminderTime) { _, newTime in
                                Task {
                                    NotificationScheduler.shared.cancelDailyReminder()
                                    await NotificationScheduler.shared.scheduleDailyReminder(time: newTime)
                                }
                            }

                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            Label("通知详情设置", systemImage: "bell.badge")
                        }
                    }
                } header: {
                    Text("通知")
                } footer: {
                    Text("开启通知后，APP即使被划掉也能在设定时间发送通知提醒。")
                }

                // MARK: 外观设置
                Section {
                    Picker("外观模式", selection: $darkModeEnabled) {
                        Label("浅色模式", systemImage: "sun.max").tag(false)
                        Label("深色模式", systemImage: "moon").tag(true)
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("外观")
                } footer: {
                    Text("选择浅色或深色显示模式。")
                }

                // MARK: 任务默认设置
                Section {
                    Picker("默认优先级", selection: $defaultPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }

                    Picker("默认排序", selection: $defaultSort) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }

                } header: {
                    Text("任务默认设置")
                }

                // MARK: 自动备份
                Section {
                    NavigationLink {
                        BackupSettingsView()
                    } label: {
                        HStack {
                            Label("自动备份", systemImage: "arrow.clockwise.icloud")
                            Spacer()
                            Text(BackupManager.shared.settings.isEnabled ? "已开启" : "已关闭")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("备份")
                } footer: {
                    Text("配置自动备份频率和保留策略，保护您的数据安全。")
                }

                // MARK: 数据管理
                Section {
                    Button {
                        showingExportSheet = true
                    } label: {
                        Label("导出数据", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showingImportSheet = true
                    } label: {
                        Label("导入数据", systemImage: "square.and.arrow.down")
                    }

                    NavigationLink {
                        StorageInfoView()
                    } label: {
                        Label("存储信息", systemImage: "externaldrive")
                    }

                    Button {
                        showingClearCacheAlert = true
                    } label: {
                        Label("清除缓存", systemImage: "eraser")
                    }

                    Button {
                        showingResetStatsAlert = true
                    } label: {
                        Label("重置数据统计", systemImage: "arrow.counterclockwise")
                    }

                    Button(role: .destructive) {
                        showingClearDataAlert = true
                    } label: {
                        Label("清除所有数据", systemImage: "trash")
                    }
                } header: {
                    Text("数据管理")
                }

                // MARK: 快捷指令
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("URL Scheme", systemImage: "link")
                            .font(.headline)
                        Text("chengfengplan://")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("支持通过外部链接打开任务详情或快速添加任务。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("打开任务")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("chengfengplan://task/{id}")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("添加任务")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("chengfengplan://add?title=xxx&priority=high")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("快捷指令集成")
                } footer: {
                    Text("在快捷指令 App 中使用上述 URL 与乘风计划进行交互。")
                }

                // MARK: 关于
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingPrivacyPolicy = true
                    } label: {
                        Label("隐私政策", systemImage: "hand.raised")
                    }

                    if let url = URL(string: "https://example.com/support") {
                        Link(destination: url) {
                            Label("帮助与支持", systemImage: "questionmark.circle")
                        }
                    }

                    if let url = URL(string: "https://example.com/feedback") {
                        Link(destination: url) {
                            Label("反馈建议", systemImage: "envelope")
                        }
                    }

                    NavigationLink {
                        OpenSourceLicenseView()
                    } label: {
                        Label("开源许可", systemImage: "doc.text")
                    }

                    Button {
                        checkForUpdates()
                    } label: {
                        Label("检查更新", systemImage: "arrow.down.circle")
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
            .onAppear {
                loadSettings()
            }
        }
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
        .sheet(isPresented: $showingExportSheet) {
            ExportDataView()
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportDataView()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .alert("确认清除数据", isPresented: $showingClearDataAlert) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                taskStore.tasks.removeAll()
                taskStore.tags.removeAll()
                Task {
                    await taskStore.saveTasks()
                }
            }
        } message: {
            Text("此操作将清除所有任务和标签数据，且无法恢复。")
        }
        .alert("确认重置统计", isPresented: $showingResetStatsAlert) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) {
                resetStatistics()
            }
        } message: {
            Text("此操作将重置所有任务完成统计和趋势数据，且无法恢复。")
        }
        .alert("确认清除缓存", isPresented: $showingClearCacheAlert) {
            Button("取消", role: .cancel) {}
            Button("清除") {
                clearCache()
            }
        } message: {
            Text("此操作将清除临时文件和缓存数据。")
        }
    }

    // MARK: - Load Settings

    private func loadSettings() {
        apiKey = SecureStore.shared.loadString(key: "ai_api_key_\(aiProvider.rawValue)") ?? ""
        apiBaseURL = aiProvider.defaultBaseURL
        selectedModel = availableModels.first ?? ""

        // 加载版本信息
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0"
        buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        // 检查通知权限状态
        Task {
            let status = await NotificationScheduler.shared.checkAuthorizationStatus()
            await MainActor.run {
                switch status {
                case .authorized:
                    notificationPermissionStatus = "已授权"
                    notificationsEnabled = true
                case .denied:
                    notificationPermissionStatus = "被拒绝"
                    notificationsEnabled = false
                case .notDetermined:
                    notificationPermissionStatus = "未请求"
                default:
                    notificationPermissionStatus = "未知"
                }
            }
        }
    }

    private func checkForUpdates() {
        // 占位符：实际实现中可调用 App Store API 检查更新
        // 此处仅展示提示
    }

    private func clearCache() {
        let tempDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    private func resetStatistics() {
        // 重置统计相关数据
        let statsKeys = [
            "task_completion_stats",
            "daily_task_counts",
            "com.chengfengplan.pomodorosessions",
            "com.chengfengplan.moodentries"
        ]
        for key in statsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

// MARK: - BackupSettingsView

@MainActor
struct BackupSettingsView: View {
    @State private var settings: BackupSettings
    @State private var showingBackupNowAlert = false
    @State private var backupRecords: [BackupRecord] = []
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false
    @State private var isBackingUp = false

    init() {
        _settings = State(initialValue: BackupManager.shared.settings)
    }

    var body: some View {
        List {
            Section {
                Toggle("启用自动备份", isOn: $settings.isEnabled)

                if settings.isEnabled {
                    Picker("备份频率", selection: $settings.frequency) {
                        ForEach(BackupFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }

                    DatePicker("备份时间", selection: $settings.backupTime, displayedComponents: .hourAndMinute)

                    Stepper(value: $settings.retentionCount, in: 1...30) {
                        LabeledContent("保留份数", value: "\(settings.retentionCount) 份")
                    }
                }
            } header: {
                Text("备份设置")
            } footer: {
                if settings.isEnabled, let nextDate = BackupManager.shared.nextBackupDate() {
                    Text("下次备份: \(formatDate(nextDate))")
                }
            }

            if let lastDate = settings.lastBackupDate {
                Section {
                    LabeledContent("上次备份", value: formatDate(lastDate))
                }
            }

            Section {
                Button {
                    showingBackupNowAlert = true
                } label: {
                    HStack {
                        Label("立即备份", systemImage: "arrow.clockwise")
                        if isBackingUp {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isBackingUp)
            }

            if !backupRecords.isEmpty {
                Section("备份历史") {
                    ForEach(backupRecords) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.formattedDate)
                                    .font(.subheadline)
                                Text(record.formattedSize)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .onDelete(perform: deleteBackup)
                }
            }
        }
        .navigationTitle("自动备份")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { @MainActor in
                refreshBackupRecords()
            }
        }
        .onChange(of: settings) { _, newValue in
            Task { @MainActor in
                BackupManager.shared.settings = newValue
            }
        }
        .alert("确认立即备份", isPresented: $showingBackupNowAlert) {
            Button("取消", role: .cancel) {}
            Button("备份") {
                performBackupNow()
            }
        } message: {
            Text("将立即创建一份数据备份。")
        }
        .toast(message: toastMessage, isError: toastIsError, isPresented: $showToast)
    }

    private func performBackupNow() {
        Task {
            isBackingUp = true
            defer { isBackingUp = false }
            do {
                let url = try await BackupManager.shared.performBackup()
                showToast(message: "备份成功！", isError: false)
                refreshBackupRecords()
            } catch {
                showToast(message: "备份失败: \(error.localizedDescription)", isError: true)
            }
        }
    }

    @MainActor
    private func refreshBackupRecords() {
        backupRecords = BackupManager.shared.getBackupRecords()
    }

    @MainActor
    private func deleteBackup(at offsets: IndexSet) {
        for index in offsets {
            let record = backupRecords[index]
            try? BackupManager.shared.deleteBackup(url: record.url)
        }
        refreshBackupRecords()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func showToast(message: String, isError: Bool) {
        toastMessage = message
        toastIsError = isError
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showToast = false
        }
    }
}

// MARK: - StorageInfoView

struct StorageInfoView: View {
    @Environment(TaskStore.self) private var taskStore
    @State private var cacheSize: String = "计算中..."
    @State private var documentSize: String = "计算中..."

    var body: some View {
        List {
            Section("数据概览") {
                LabeledContent("任务数量", value: "\(taskStore.tasks.count)")
                LabeledContent("标签数量", value: "\(taskStore.tags.count)")
                LabeledContent("已完成任务", value: "\(taskStore.tasks.filter { $0.isCompleted }.count)")
                LabeledContent("待办任务", value: "\(taskStore.tasks.filter { !$0.isCompleted }.count)")
            }

            Section("存储占用") {
                LabeledContent("文档大小", value: documentSize)
                LabeledContent("缓存大小", value: cacheSize)
            }
        }
        .navigationTitle("存储信息")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calculateSizes()
        }
    }

    private func calculateSizes() {
        Task {
            let fileManager = FileManager.default
            let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let temp = fileManager.temporaryDirectory

            let docSize = await directorySize(url: docs)
            let tempSize = await directorySize(url: temp)

            await MainActor.run {
                documentSize = ByteCountFormatter.string(fromByteCount: docSize, countStyle: .file)
                cacheSize = ByteCountFormatter.string(fromByteCount: tempSize, countStyle: .file)
            }
        }
    }

    private nonisolated func directorySize(url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}

// MARK: - OpenSourceLicenseView

struct OpenSourceLicenseView: View {
    @Environment(\.dismiss) private var dismiss

    let licenses = [
        ("SwiftUI", "Apple Inc.", "Apple 专有许可"),
        ("Foundation", "Apple Inc.", "Apple 专有许可"),
        ("UserNotifications", "Apple Inc.", "Apple 专有许可"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(licenses, id: \.0) { name, author, license in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name)
                                .font(.headline)
                            Text("作者: \(author)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("许可: \(license)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("使用的开源/系统库")
                } footer: {
                    Text("乘风计划感谢所有开源社区贡献者。")
                }
            }
            .navigationTitle("开源许可")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - NotificationSettingsView

struct NotificationSettingsView: View {
    @State private var taskReminderEnabled = true
    @State private var overdueReminderEnabled = true
    @State private var dailyReminderEnabled = true
    @State private var soundEnabled = true

    var body: some View {
        List {
            Section("提醒类型") {
                Toggle("任务截止提醒", isOn: $taskReminderEnabled)
                Toggle("逾期任务提醒", isOn: $overdueReminderEnabled)
                Toggle("每日任务提醒", isOn: $dailyReminderEnabled)
            }

            Section("提醒方式") {
                Toggle("声音", isOn: $soundEnabled)
            }

            Section {
                Button {
                    NotificationScheduler.shared.cancelAllNotifications()
                } label: {
                    Label("清除所有待发送通知", systemImage: "bell.slash")
                }
            }
        }
        .navigationTitle("通知详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ExportDataView

struct ExportDataView: View {
    @Environment(TaskStore.self) private var taskStore
    @Environment(\.dismiss) private var dismiss

    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showFileExporter = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.themePrimary)

                Text("导出数据")
                    .font(.title2.bold())

                Text("您的任务数据将被导出为 JSON 格式文件，可在文件 App 中查看。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("任务数量")
                        Spacer()
                        Text("\(taskStore.tasks.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("标签数量")
                        Spacer()
                        Text("\(taskStore.tags.count)")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Button {
                    performExport()
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isExporting ? "导出中..." : "导出")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.themePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isExporting)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("导出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .fileExporter(
                isPresented: $showFileExporter,
                document: ExportDocument(url: exportURL),
                contentType: .json,
                defaultFilename: exportURL?.lastPathComponent ?? "ChengFengPlan_Export.json"
            ) { result in
                handleExportResult(result)
            }
            .toast(message: toastMessage, isError: toastIsError, isPresented: $showToast)
        }
    }

    private func performExport() {
        Task {
            isExporting = true
            defer { isExporting = false }

            do {
                let url = try await FileSyncManager.shared.exportToURL(
                    tasks: taskStore.tasks,
                    tags: taskStore.tags
                )
                exportURL = url
                showFileExporter = true
            } catch {
                showToast(message: error.localizedDescription, isError: true)
            }
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let savedURL):
            showToast(message: "导出成功！文件已保存", isError: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        case .failure(let error):
            showToast(message: "保存失败: \(error.localizedDescription)", isError: true)
        }
    }

    private func showToast(message: String, isError: Bool) {
        toastMessage = message
        toastIsError = isError
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showToast = false
        }
    }
}

// MARK: - ExportDocument (for fileExporter)

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let url: URL?

    init(url: URL?) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        self.url = nil
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url = url else {
            throw FileSyncError.fileNotAccessible
        }
        let data = try Data(contentsOf: url)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - ImportDataView

struct ImportDataView: View {
    @Environment(TaskStore.self) private var taskStore
    @Environment(\.dismiss) private var dismiss

    @State private var isImporting = false
    @State private var showFileImporter = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false
    @State private var importResult: ImportResult?
    @State private var showConfirmAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.themeSecondary)

                Text("导入数据")
                    .font(.title2.bold())

                Text("选择乘风计划导出的 JSON 文件，导入的任务和标签将合并到现有数据中。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    Label("支持导入乘风计划导出的 JSON 文件", systemImage: "checkmark.circle")
                    Label("导入的数据将与现有数据合并", systemImage: "checkmark.circle")
                    Label("重复的任务 ID 将被覆盖", systemImage: "exclamationmark.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Button {
                    showFileImporter = true
                } label: {
                    HStack {
                        if isImporting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isImporting ? "导入中..." : "选择文件")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.themeSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isImporting)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert("确认导入", isPresented: $showConfirmAlert) {
                Button("取消", role: .cancel) {}
                Button("导入") {
                    if let result = importResult {
                        applyImport(result)
                    }
                }
            } message: {
                if let result = importResult {
                    Text("即将导入 \(result.taskCount) 个任务和 \(result.tagCount) 个标签，是否继续？")
                } else {
                    Text("确认导入数据？")
                }
            }
            .toast(message: toastMessage, isError: toastIsError, isPresented: $showToast)
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                showToast(message: "未选择文件", isError: true)
                return
            }
            performImport(from: url)
        case .failure(let error):
            showToast(message: "选择文件失败: \(error.localizedDescription)", isError: true)
        }
    }

    private func performImport(from url: URL) {
        Task {
            isImporting = true
            defer { isImporting = false }

            do {
                let result = try await FileSyncManager.shared.importFromURL(url)
                importResult = result
                showConfirmAlert = true
            } catch {
                showToast(message: error.localizedDescription, isError: true)
            }
        }
    }

    @MainActor
    private func applyImport(_ result: ImportResult) {
        let existingTagIds = Set(taskStore.tags.map { $0.id })
        let newTags = result.tags.filter { !existingTagIds.contains($0.id) }
        taskStore.tags.append(contentsOf: newTags)

        let existingTaskIds = Set(taskStore.tasks.map { $0.id })
        let newTasks = result.tasks.filter { !existingTaskIds.contains($0.id) }

        for importedTask in result.tasks {
            if let index = taskStore.tasks.firstIndex(where: { $0.id == importedTask.id }) {
                taskStore.tasks[index] = importedTask
            }
        }
        taskStore.tasks.append(contentsOf: newTasks)

        Task { @MainActor in
            await taskStore.saveTasks()
        }

        showToast(message: "成功导入 \(result.tasks.count) 个任务、\(result.tags.count) 个标签", isError: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }

    private func showToast(message: String, isError: Bool) {
        toastMessage = message
        toastIsError = isError
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showToast = false
        }
    }
}

// MARK: - PrivacyPolicyView

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("隐私政策")
                        .font(.title.bold())

                    Text("最后更新日期：2025年1月1日")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    policySection(title: "数据收集", content: "乘风计划仅收集您主动输入的任务数据。我们不会收集任何个人信息用于广告或营销目的。")

                    policySection(title: "数据存储", content: "您的所有数据默认存储在本地设备上。数据文件保存在 App 的文档目录中，不会上传到任何服务器。")

                    policySection(title: "AI 服务", content: "当您使用 AI 助手功能时，任务标题和描述可能会被发送到您选择的 AI 提供商。我们不会存储或分析这些请求。")

                    policySection(title: "数据安全", content: "敏感信息（如 API Key）使用设备的安全存储进行加密保存。本地数据备份也存储在设备本地。")
                }
                .padding()
            }
            .navigationTitle("隐私政策")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func policySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(TaskStore.shared)
}
