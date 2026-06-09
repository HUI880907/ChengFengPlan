// MARK: - ChengFengPlanApp.swift
// 乘风计划 - iOS 待办事项管理应用
// App 入口

import SwiftUI

@main
struct ChengFengPlanApp: App {
    @State private var taskStore = TaskStore.shared
    @State private var aiManager = AIManager.shared
    @State private var trashManager = TrashManager.shared
    @State private var pomodoroManager = PomodoroManager.shared
    @State private var moodTracker = MoodTracker.shared
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    init() {
        // 配置全局外观
        configureAppearance()
        
        // 请求通知权限（在 Task 中异步调用，不阻塞 init）
        Task {
            await NotificationScheduler.shared.requestAuthorization()
        }
        
        // 注册全局错误处理
        setupErrorHandling()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(taskStore)
                .environment(aiManager)
                .environment(trashManager)
                .environment(pomodoroManager)
                .environment(moodTracker)
                .alert("错误", isPresented: $showingErrorAlert) {
                    Button("确定", role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
                .onOpenURL { url in
                    URLSchemeHandler.shared.handle(url: url)
                }
        }
    }
    
    // MARK: - Private Methods
    
    private func configureAppearance() {
        // 配置导航栏外观
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    private func setupErrorHandling() {
        // 全局错误处理
        Task {
            for await error in ErrorPublisher.shared.errors {
                await MainActor.run {
                    errorMessage = error
                    showingErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Error Publisher

@Observable
final class ErrorPublisher {
    static let shared = ErrorPublisher()
    
    private(set) var errors: AsyncStream<String> {
        get { _errors }
        set { _errors = newValue }
    }
    private var _errors: AsyncStream<String>!
    private var continuation: AsyncStream<String>.Continuation!
    
    private init() {
        _errors = AsyncStream { continuation in
            self.continuation = continuation
        }
    }
    
    func publish(_ error: String) {
        continuation.yield(error)
    }
}
