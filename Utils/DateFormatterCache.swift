// MARK: - DateFormatterCache.swift
// 乘风计划 - 日期格式化器缓存

import Foundation

// MARK: - DateFormatterCache

/// 日期格式化器缓存，避免重复创建
final class DateFormatterCache {

    // MARK: - Shared Instance

    static let shared = DateFormatterCache()

    // MARK: - Formatters

    let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    let fullDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - Initialization

    private init() {}

    // MARK: - Format Methods

    /// 格式样式
    enum FormatStyle {
        case full, medium, short, time
    }

    /// 格式化日期
    func format(_ date: Date, style: FormatStyle) -> String {
        switch style {
        case .full:
            return fullDateTimeFormatter.string(from: date)
        case .medium:
            return mediumDateFormatter.string(from: date)
        case .short, .time:
            return shortTimeFormatter.string(from: date)
        }
    }

    /// 获取月份年份字符串
    func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}
