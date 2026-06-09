// MARK: - SearchView.swift
// 乘风计划 - 搜索视图

import SwiftUI

// MARK: - SearchResultType

enum SearchResultType: String, CaseIterable {
    case all = "全部"
    case task = "任务"
    case tag = "标签"
    case log = "日志"
}

// MARK: - SearchView

struct SearchView: View {
    @Environment(TaskStore.self) private var taskStore
    @State private var searchText = ""
    @State private var selectedType: SearchResultType = .all
    @State private var searchHistory: [String] = ["项目", "紧急", "周报"]
    @State private var showingAdvancedFilter = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: Search Bar
                searchBarSection

                // MARK: Result Type Filter
                if !searchText.isEmpty {
                    resultTypeFilter
                }

                // MARK: Content
                if searchText.isEmpty {
                    searchHistorySection
                } else {
                    SearchResultsList(searchText: searchText)
                }
            }
            .navigationTitle("搜索")
        }
    }

    // MARK: - Search Bar Section

    private var searchBarSection: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("搜索任务、标签...", text: $searchText)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                showingAdvancedFilter = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title3)
                    .foregroundStyle(Color.themePrimary)
            }
        }
        .padding()
    }

    // MARK: - Result Type Filter

    private var resultTypeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchResultType.allCases, id: \.self) { type in
                    Button {
                        selectedType = type
                    } label: {
                        Text(type.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(selectedType == type ? Color.themePrimary : Color(.systemGray6))
                            .foregroundStyle(selectedType == type ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Search History Section

    private var searchHistorySection: some View {
        List {
            Section {
                ForEach(searchHistory, id: \.self) { item in
                    Button {
                        searchText = item
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.secondary)
                            Text(item)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                }
                .onDelete { indexSet in
                    searchHistory.remove(atOffsets: indexSet)
                }
            } header: {
                HStack {
                    Text("搜索历史")
                    Spacer()
                    Button("清除") {
                        searchHistory.removeAll()
                    }
                    .font(.caption)
                    .foregroundStyle(Color.themePrimary)
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - SearchResultsList

private struct SearchResultsList: View {
    @Environment(TaskStore.self) private var taskStore
    let searchText: String

    var body: some View {
        let results = taskStore.searchTasks(query: searchText)
        List {
            if !results.isEmpty {
                Section("任务") {
                    ForEach(results) { task in
                        HStack {
                            Circle()
                                .fill(task.priority.color)
                                .frame(width: 8, height: 8)
                            Text(task.title)
                            Spacer()
                        }
                    }
                }
            } else {
                Section {
                    ContentUnavailableView {
                        Label("未找到结果", systemImage: "magnifyingglass")
                    } description: {
                        Text("尝试其他关键词")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    SearchView()
}
