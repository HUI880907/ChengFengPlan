// MARK: - ContentView.swift
// 乘风计划 - 主入口视图

import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showingBriefing = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: 任务列表
            TaskListView()
                .tabItem {
                    Label("任务", systemImage: "list.bullet")
                }
                .tag(0)

            // MARK: 看板
            KanbanBoardView()
                .tabItem {
                    Label("看板", systemImage: "columns")
                }
                .tag(1)

            // MARK: 日历
            CalendarView()
                .tabItem {
                    Label("日历", systemImage: "calendar")
                }
                .tag(2)

            // MARK: 统计
            StatisticsView()
                .tabItem {
                    Label("统计", systemImage: "chart.bar")
                }
                .tag(3)

            // MARK: AI助手
            AIAssistantView()
                .tabItem {
                    Label("AI助手", systemImage: "sparkles")
                }
                .tag(4)

            // MARK: 设置
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(5)
        }
        .overlay(alignment: .topTrailing) {
            dailyBriefingButton
        }
        .sheet(isPresented: $showingBriefing) {
            DailyBriefingView()
        }
    }

    // MARK: - Daily Briefing Button

    private var dailyBriefingButton: some View {
        Button {
            showingBriefing = true
        } label: {
            Image(systemName: "sunrise.fill")
                .font(.title3)
                .foregroundStyle(.orange)
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .padding(.top, 8)
        .padding(.trailing, 16)
    }
}

// MARK: - DailyBriefingView

struct DailyBriefingView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("今日简报")
                        .font(.largeTitle.bold())

                    briefingSection(title: "待办任务", icon: "checklist", color: .blue) {
                        Text("您今天有 3 项待办任务")
                    }

                    briefingSection(title: "逾期提醒", icon: "exclamationmark.triangle", color: .red) {
                        Text("有 1 项任务已逾期")
                    }

                    briefingSection(title: "今日专注", icon: "brain.head.profile", color: .purple) {
                        Text("建议优先处理高优先级任务")
                    }
                }
                .padding()
            }
            .navigationTitle("每日简报")
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

    private func briefingSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
            content()
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
