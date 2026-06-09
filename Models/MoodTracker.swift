import Foundation

// MARK: - MoodEntry

struct MoodEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    var moodLevel: Int
    var energyLevel: Int
    var note: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        moodLevel: Int,
        energyLevel: Int,
        note: String = ""
    ) {
        self.id = id
        self.date = date
        self.moodLevel = max(1, min(5, moodLevel))
        self.energyLevel = max(1, min(5, energyLevel))
        self.note = note
    }

    var moodDescription: String {
        switch moodLevel {
        case 1: return "非常低落"
        case 2: return "低落"
        case 3: return "一般"
        case 4: return "愉快"
        case 5: return "非常开心"
        default: return "未知"
        }
    }

    var energyDescription: String {
        switch energyLevel {
        case 1: return "非常疲惫"
        case 2: return "疲惫"
        case 3: return "一般"
        case 4: return "精力充沛"
        case 5: return "能量满满"
        default: return "未知"
        }
    }
}

// MARK: - MoodTracker

@MainActor
@Observable
final class MoodTracker {

    // MARK: - Singleton

    static let shared = MoodTracker()

    // MARK: - Properties

    var entries: [MoodEntry] = []

    private let entriesKey = "com.chengfengplan.moodentries"

    var entryCount: Int {
        entries.count
    }

    var isEmpty: Bool {
        entries.isEmpty
    }

    var latestEntry: MoodEntry? {
        entries.sorted { $0.date > $1.date }.first
    }

    // MARK: - Initialization

    private init() {
        loadEntries()
    }

    // MARK: - Persistence

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: entriesKey) else { return }
        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode([MoodEntry].self, from: data)
            entries = decoded
        } catch {
            print("[MoodTracker] Failed to load entries: \(error)")
        }
    }

    private func saveEntries() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(entries)
            UserDefaults.standard.set(data, forKey: entriesKey)
        } catch {
            print("[MoodTracker] Failed to save entries: \(error)")
        }
    }

    // MARK: - CRUD Operations

    /// 添加情绪记录
    func addEntry(mood: Int, energy: Int, note: String = "", date: Date = Date()) {
        let entry = MoodEntry(
            date: date,
            moodLevel: mood,
            energyLevel: energy,
            note: note
        )
        entries.append(entry)
        saveEntries()
    }

    /// 更新已有记录
    func updateEntry(_ entry: MoodEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            saveEntries()
        }
    }

    /// 删除指定记录
    func removeEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        saveEntries()
    }

    /// 删除日期范围内的记录
    func removeEntries(in range: ClosedRange<Date>) {
        entries.removeAll { range.contains($0.date) }
        saveEntries()
    }

    // MARK: - Query Methods

    /// 获取指定日期范围内的记录
    func getEntriesForDateRange(from startDate: Date, to endDate: Date) -> [MoodEntry] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate

        return entries
            .filter { $0.date >= start && $0.date <= end }
            .sorted { $0.date < $1.date }
    }

    /// 获取指定日期的记录
    func getEntriesForDate(_ date: Date) -> [MoodEntry] {
        let calendar = Calendar.current
        return entries
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    /// 获取最近 N 条记录
    func getRecentEntries(count: Int) -> [MoodEntry] {
        entries
            .sorted { $0.date > $1.date }
            .prefix(count)
            .map { $0 }
    }

    // MARK: - Statistics

    /// 计算平均情绪值
    func getAverageMood(for entries: [MoodEntry]? = nil) -> Double {
        let targetEntries = entries ?? self.entries
        guard !targetEntries.isEmpty else { return 0 }
        let sum = targetEntries.reduce(0) { $0 + $1.moodLevel }
        return Double(sum) / Double(targetEntries.count)
    }

    /// 计算平均能量值
    func getAverageEnergy(for entries: [MoodEntry]? = nil) -> Double {
        let targetEntries = entries ?? self.entries
        guard !targetEntries.isEmpty else { return 0 }
        let sum = targetEntries.reduce(0) { $0 + $1.energyLevel }
        return Double(sum) / Double(targetEntries.count)
    }

    /// 获取指定日期范围的平均情绪值
    func getAverageMoodForDateRange(from startDate: Date, to endDate: Date) -> Double {
        let rangeEntries = getEntriesForDateRange(from: startDate, to: endDate)
        return getAverageMood(for: rangeEntries)
    }

    /// 获取指定日期范围的平均能量值
    func getAverageEnergyForDateRange(from startDate: Date, to endDate: Date) -> Double {
        let rangeEntries = getEntriesForDateRange(from: startDate, to: endDate)
        return getAverageEnergy(for: rangeEntries)
    }

    /// 获取情绪趋势（按天聚合）
    func getMoodTrend(for days: Int) -> [(date: Date, avgMood: Double, avgEnergy: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var trend: [(date: Date, avgMood: Double, avgEnergy: Double)] = []

        for dayOffset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }
            let dayEntries = getEntriesForDate(date)
            let avgMood = getAverageMood(for: dayEntries)
            let avgEnergy = getAverageEnergy(for: dayEntries)
            trend.append((date: date, avgMood: avgMood, avgEnergy: avgEnergy))
        }

        return trend
    }

    /// 获取情绪分布统计
    func getMoodDistribution(for entries: [MoodEntry]? = nil) -> [Int: Int] {
        let targetEntries = entries ?? self.entries
        var distribution: [Int: Int] = [:]
        for entry in targetEntries {
            distribution[entry.moodLevel, default: 0] += 1
        }
        return distribution
    }

    /// 获取能量分布统计
    func getEnergyDistribution(for entries: [MoodEntry]? = nil) -> [Int: Int] {
        let targetEntries = entries ?? self.entries
        var distribution: [Int: Int] = [:]
        for entry in targetEntries {
            distribution[entry.energyLevel, default: 0] += 1
        }
        return distribution
    }

    // MARK: - Data Management

    func clearAllEntries() {
        entries.removeAll()
        saveEntries()
    }

    func clearEntriesBefore(_ date: Date) {
        entries.removeAll { $0.date < date }
        saveEntries()
    }
}
