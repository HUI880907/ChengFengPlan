// MARK: - AddLogEntryView.swift
// 乘风计划 - 添加日志视图

import SwiftUI

// MARK: - AddLogEntryView

struct AddLogEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var selectedType: LogType = .progress
    @FocusState private var isContentFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                // MARK: 日志类型
                Section("日志类型") {
                    Picker("类型", selection: $selectedType) {
                        ForEach(LogType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundStyle(type.color)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: 日志内容
                Section("内容") {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                        .focused($isContentFocused)
                }

                // MARK: 预览
                if !content.isEmpty {
                    Section("预览") {
                        LogEntryRow(log: LogEntry(content: content, type: selectedType))
                    }
                }
            }
            .navigationTitle("添加日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveLog()
                    }
                    .disabled(content.isEmpty)
                }
            }
            .onAppear {
                isContentFocused = true
            }
        }
    }

    // MARK: - Methods

    private func saveLog() {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // 保存日志逻辑
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    AddLogEntryView()
}
