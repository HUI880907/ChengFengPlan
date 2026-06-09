// MARK: - DateRangeCalculator.swift
// 乘风计划 - 日期范围计算工具

import Foundation

// MARK: - DateRangeCalculator

final class DateRangeCalculator {

    static let shared = DateRangeCalculator()

    private init() {}

    // MARK: - Start / End of Day

    func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    func endOfDay(_ date: Date) -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay(date)) ?? date
    }

    // MARK: - Start / End of Week

    func startOfWeek(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    func endOfWeek(_ date: Date) -> Date {
        var components = DateComponents()
        components.weekOfYear = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfWeek(date)) ?? date
    }

    // MARK: - Start / End of Month

    func startOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    func endOfMonth(_ date: Date) -> Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfMonth(date)) ?? date
    }

    // MARK: - Helpers

    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    func isOverdue(_ date: Date) -> Bool {
        date < Date()
    }

    func timeRemaining(_ date: Date) -> String {
        let now = Date()
        if now > date {
            return "已逾期"
        }

        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: date)
        if let day = components.day, day > 0 {
            return "剩余 \(day) 天"
        } else if let hour = components.hour, hour > 0 {
            return "剩余 \(hour) 小时"
        } else if let minute = components.minute, minute > 0 {
            return "剩余 \(minute) 分钟"
        }
        return "即将到期"
    }
}
