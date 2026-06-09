// MARK: - ColorExtensions.swift
// 乘风计划 - 颜色扩展

import SwiftUI

// MARK: - Color Extension

extension Color {

    // MARK: - Priority Colors

    static var priorityLow: Color {
        Color(hex: "#34C759")
    }

    static var priorityMedium: Color {
        Color(hex: "#007AFF")
    }

    static var priorityHigh: Color {
        Color(hex: "#FF9500")
    }

    static var priorityUrgent: Color {
        Color(hex: "#FF3B30")
    }

    // MARK: - Status Colors

    static var statusPending: Color {
        Color(hex: "#8E8E93")
    }

    static var statusInProgress: Color {
        Color(hex: "#5856D6")
    }

    static var statusCompleted: Color {
        Color(hex: "#34C759")
    }

    static var statusCancelled: Color {
        Color(hex: "#FF3B30")
    }

    // MARK: - Theme Colors

    static var themePrimary: Color {
        Color(hex: "#007AFF")
    }

    static var themeSecondary: Color {
        Color(hex: "#5856D6")
    }

    static var themeBackground: Color {
        Color(hex: "#F2F2F7")
    }

    // MARK: - Hex Initializer

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        if let parsed = UInt64(hex, radix: 16) {
            int = parsed
        }
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - TaskPriority Color Extension

extension TaskPriority {
    /// 优先级对应的颜色
    var color: Color {
        switch self {
        case .low: return .priorityLow
        case .medium: return .priorityMedium
        case .high: return .priorityHigh
        case .urgent: return .priorityUrgent
        }
    }
}

// MARK: - TaskStatus Color Extension

extension TaskStatus {
    /// 状态对应的颜色
    var color: Color {
        switch self {
        case .pending: return .statusPending
        case .inProgress: return .statusInProgress
        case .completed: return .statusCompleted
        case .cancelled: return .statusCancelled
        }
    }
}
