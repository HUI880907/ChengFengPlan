// MARK: - SettingsView.swift
// 乘风计划 - 设置视图

import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @State private var aiProvider: AIProvider = .zhipu
    @State private var apiKey = ""
    @State private var selectedModel = ""
    @State private var notificationsEnabled = true
    @State private var reminderTime = Date()
    @State private var themeColor: Color = .blue
    @State private var darkModeEnabled = false
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var showingPrivacyPolicy = false
    @State private var appVersion = "2.0.0"

    /// 根据 AI 提供商返回对应的模型列表
    private var availableModels: [String] {
        switch aiProvider {
        case .zhipu:
            return ["glm-4", "glm-4-plus", "glm-4-flash"]
        case .tongyi:
            return ["qwen-max", "qwen-plus", "qwen-turbo"]
        case .wenxin:
            return ["ernie-4.0", "ernie-3.5", "ernie-speed"]
        case .spark:
            return ["spark-v4.0", "spark-v3.5", "spark-v3.0"]
        case .moonshot:
            return ["moonshot-v1-128k", "moonshot-v1-32k", "moonshot-v1-8k"]
        case .minimax:
            return ["abab6.5s", "abab6", "abab5.5"]
        case .zeroOne:
            return ["yi-large", "yi-medium", "yi-spark"]
        case .custom:
            return ["custom"]
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: AI 设置
                Section("AI 设置") {
                    Picker("提供商", selection: $aiProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }

                    SecureField("API Key", text: $apiKey)
                        .onChange(of: apiKey) { _, newValue in
                            SecureStore.shared.saveString(key: "ai_api_key_\(aiProvider.rawValue)", value: newValue)
                        }

                    Picker("模型", selection: $selectedModel) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .onChange(of: aiProvider) { _, _ in
                        selectedModel = availableModels.first ?? ""
                    }
                }

                // MARK: 通知设置
                Section("通知") {
                    Toggle("启用通知", isOn: $notificationsEnabled)

                    if notificationsEnabled {
                        DatePicker("每日提醒时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                // MARK: 外观设置
                Section("外观") {
                    ColorPicker("主题色", selection: $themeColor)
                    Toggle("深色模式", isOn: $darkModeEnabled)
                }

                // MARK: 数据管理
                Section("数据管理") {
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

                    Button {
                        // 备份逻辑
                    } label: {
                        Label("备份到 iCloud", systemImage: "icloud.and.arrow.up")
                    }

                    Button {
                        // 恢复逻辑
                    } label: {
                        Label("从 iCloud 恢复", systemImage: "icloud.and.arrow.down")
                    }
                }

                // MARK: 关于
                Section("关于") {
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
                }
            }
            .navigationTitle("设置")
        }
        .preferredColorScheme(darkModeEnabled ? .dark : nil)
        .sheet(isPresented: $showingExportSheet) {
            ExportDataView()
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportDataView()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
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
                    .foregroundStyle(.themePrimary)

                Text("导出数据")
                    .font(.title2.bold())

                Text("您的任务数据将被导出为 JSON 格式文件")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    // 执行导出
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
                    .foregroundStyle(.themeSecondary)

                Text("导入数据")
                    .font(.title2.bold())

                Text("选择 JSON 文件导入任务数据")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    // 执行导入
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

                    Text("最后更新日期：2024年1月1日")
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
}
