import Foundation
import Combine

// MARK: - PomodoroSession

struct PomodoroSession: Identifiable, Codable, Equatable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    let duration: TimeInterval
    var isCompleted: Bool
    let taskId: UUID?

    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        duration: TimeInterval,
        isCompleted: Bool = false,
        taskId: UUID? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.isCompleted = isCompleted
        self.taskId = taskId
    }

    var actualDuration: TimeInterval {
        if let end = endTime {
            return end.timeIntervalSince(startTime)
        }
        return Date().timeIntervalSince(startTime)
    }

    var remainingTime: TimeInterval {
        max(0, duration - actualDuration)
    }

    var progress: Double {
        min(1.0, actualDuration / duration)
    }
}

// MARK: - PomodoroDailyStats

struct PomodoroDailyStats: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let completedSessions: Int
    let totalFocusTime: TimeInterval
    let completedTasks: Int
}

// MARK: - PomodoroManager

@MainActor
@Observable
final class PomodoroManager {

    // MARK: - Singleton

    static let shared = PomodoroManager()

    // MARK: - Properties

    var isRunning: Bool = false
    var currentSession: PomodoroSession?
    var sessions: [PomodoroSession] = []
    var defaultDuration: TimeInterval = 25 * 60 // 25分钟

    private var timerCancellable: AnyCancellable?
    private let sessionsKey = "com.chengfengplan.pomodorosessions"

    var currentRemainingTime: TimeInterval {
        currentSession?.remainingTime ?? 0
    }

    var currentProgress: Double {
        currentSession?.progress ?? 0
    }

    var todayCompletedSessions: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return sessions.filter {
            $0.isCompleted && calendar.isDate($0.startTime, inSameDayAs: today)
        }.count
    }

    var todayTotalFocusTime: TimeInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return sessions
            .filter { $0.isCompleted && calendar.isDate($0.startTime, inSameDayAs: today) }
            .reduce(0) { $0 + $1.actualDuration }
    }

    // MARK: - Initialization

    private init() {
        loadSessions()
    }

    deinit {
        timerCancellable?.cancel()
    }

    // MARK: - Persistence

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey) else { return }
        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode([PomodoroSession].self, from: data)
            sessions = decoded
        } catch {
            print("[PomodoroManager] Failed to load sessions: \(error)")
        }
    }

    private func saveSessions() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(sessions)
            UserDefaults.standard.set(data, forKey: sessionsKey)
        } catch {
            print("[PomodoroManager] Failed to save sessions: \(error)")
        }
    }

    // MARK: - Timer Control

    func startSession(taskId: UUID? = nil, duration: TimeInterval? = nil) {
        let sessionDuration = duration ?? defaultDuration
        let newSession = PomodoroSession(
            duration: sessionDuration,
            taskId: taskId
        )

        currentSession = newSession
        isRunning = true

        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.checkSessionCompletion()
                }
            }
    }

    func pauseSession() {
        isRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func resumeSession() {
        guard currentSession != nil else { return }
        isRunning = true

        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.checkSessionCompletion()
                }
            }
    }

    func completeSession() {
        guard currentSession != nil else { return }

        timerCancellable?.cancel()
        timerCancellable = nil

        currentSession?.endTime = Date()
        currentSession?.isCompleted = true

        if let session = currentSession {
            sessions.append(session)
            saveSessions()
        }

        currentSession = nil
        isRunning = false
    }

    func cancelSession() {
        timerCancellable?.cancel()
        timerCancellable = nil
        currentSession = nil
        isRunning = false
    }

    private func checkSessionCompletion() {
        guard let session = currentSession else { return }
        if session.remainingTime <= 0 {
            completeSession()
        }
    }

    // MARK: - Statistics

    func getDailyStats(for date: Date = Date()) -> PomodoroDailyStats {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        let daySessions = sessions.filter {
            calendar.isDate($0.startTime, inSameDayAs: dayStart) && $0.isCompleted
        }

        let completedCount = daySessions.count
        let totalTime = daySessions.reduce(0) { $0 + $1.actualDuration }
        let uniqueTasks = Set(daySessions.compactMap { $0.taskId }).count

        return PomodoroDailyStats(
            date: dayStart,
            completedSessions: completedCount,
            totalFocusTime: totalTime,
            completedTasks: uniqueTasks
        )
    }

    func getWeeklyStats(for date: Date = Date()) -> [PomodoroDailyStats] {
        let calendar = Calendar.current
        guard let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        ) else {
            return []
        }

        var stats: [PomodoroDailyStats] = []
        for dayOffset in 0..<7 {
            if let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                stats.append(getDailyStats(for: dayDate))
            }
        }
        return stats
    }

    func getStatsForDateRange(from startDate: Date, to endDate: Date) -> [PomodoroDailyStats] {
        let calendar = Calendar.current
        var stats: [PomodoroDailyStats] = []

        var currentDate = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        while currentDate <= endDay {
            stats.append(getDailyStats(for: currentDate))
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return stats
    }

    func getTotalFocusTime(for taskId: UUID) -> TimeInterval {
        sessions
            .filter { $0.taskId == taskId && $0.isCompleted }
            .reduce(0) { $0 + $1.actualDuration }
    }

    func getSessionCount(for taskId: UUID) -> Int {
        sessions.filter { $0.taskId == taskId && $0.isCompleted }.count
    }

    // MARK: - Data Management

    func clearAllSessions() {
        sessions.removeAll()
        saveSessions()
    }

    func clearSessionsBefore(_ date: Date) {
        sessions.removeAll { $0.startTime < date }
        saveSessions()
    }
}
