// MARK: - SettingsView.swift
// 乘风计划 - 设置视图

import SwiftUI

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
    @State private var darkModeEnabled = false
    @State private var appIcon = 0
    @State private var defaultPriority: TaskPriority = .medium
    @State private var defaultSort: SortOption = .dueDate
    @State private var showCompletedTasks = true
    @State private var autoBackupEnabled = false
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var showingPrivacyPolicy = false
    @State private var showingClearDataAlert = false
    @State private var appVersion = "3.0.0"

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
                        Link(destination: URL(string: providerAPIKeyURL)!) {
                            HStack {
                                Label("获取 API Key", systemImage: "link")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundStyle(.secondary)
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
                        .foregroundStyle(apiKey.isEmpty ? .secondary : .green)
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

                    Toggle("显示已完成任务", isOn: $showCompletedTasks)
                } header: {
                    Text("任务默认设置")
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

                    Toggle("自动备份", isOn: $autoBackupEnabled)

                    Button(role: .destructive) {
                        showingClearDataAlert = true
                    } label: {
                        Label("清除所有数据", systemImage: "trash")
                    }
                } header: {
                    Text("数据管理")
                }

                // MARK: 关于
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingPrivacyPolicy = true
                    } label: {
                        Label("隐私政策", systemImage: "hand.raised")
                    }

                    Link(destination: URL(string: "https://example.com/support")!) {
                        Label("帮助与支持", systemImage: "questionmark.circle")
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
            }
        } message: {
            Text("此操作将清除所有任务和标签数据，且无法恢复。")
        }
    }

    // MARK: - Load Settings

    private func loadSettings() {
        apiKey = SecureStore.shared.loadString(key: "ai_api_key_\(aiProvider.rawValue)") ?? ""
        apiBaseURL = aiProvider.defaultBaseURL
        selectedModel = availableModels.first ?? ""

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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.themePrimary)

                Text("导出数据")
                    .font(.title2.bold())

                Text("您的任务数据将被导出为 JSON 格式文件")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    dismiss()
                } label: {
                    Text("导出")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.themePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
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
        }
    }
}

// MARK: - ImportDataView

struct ImportDataView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.themeSecondary)

                Text("导入数据")
                    .font(.title2.bold())

                Text("选择 JSON 文件导入任务数据")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    dismiss()
                } label: {
                    Text("选择文件")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.themeSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
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

                    policySection(title: "数据存储", content: "您的所有数据默认存储在本地设备上。如果您启用了 iCloud 同步，数据将被加密后存储在您的 iCloud 账户中。")

                    policySection(title: "AI 服务", content: "当您使用 AI 助手功能时，任务标题和描述可能会被发送到您选择的 AI 提供商。我们不会存储或分析这些请求。")

                    policySection(title: "数据安全", content: "敏感信息（如 API Key）使用设备的安全存储进行加密保存。")
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
