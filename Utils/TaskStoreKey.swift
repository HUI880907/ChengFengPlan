// MARK: - TaskStoreKey.swift
// 乘风计划 - 环境变量键

import SwiftUI

// MARK: - TaskStoreKey

struct TaskStoreKey: EnvironmentKey {
    static let defaultValue: TaskStore = TaskStore.shared
}

// MARK: - EnvironmentValues Extension

extension EnvironmentValues {
    var taskStore: TaskStore {
        get { self[TaskStoreKey.self] }
        set { self[TaskStoreKey.self] = newValue }
    }
}
