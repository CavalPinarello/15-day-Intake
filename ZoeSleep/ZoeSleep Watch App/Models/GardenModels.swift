//
//  GardenModels.swift
//  ZoeSleep Watch App
//
//  Models for the weekly garden visualization.
//  Each day's compliance causes a flower to bloom through 6 stages.
//

import SwiftUI

// MARK: - Bloom State

/// Bloom state for a single day's flower
/// Each check-in completed advances the bloom state
enum BloomState: Int, CaseIterable, Codable {
    case empty = 0      // Future day - no pot
    case seed = 1       // Day started, no check-ins yet
    case sprout = 2     // 1 check-in done
    case budding = 3    // 2 check-ins done
    case blooming = 4   // All 3 check-ins done
    case fullBloom = 5  // All check-ins + all tasks done (perfect day)

    /// Display label for the bloom state
    var label: String {
        switch self {
        case .empty: return "Future"
        case .seed: return "Planted"
        case .sprout: return "Growing"
        case .budding: return "Budding"
        case .blooming: return "Blooming"
        case .fullBloom: return "Full Bloom"
        }
    }

    /// Height scale for the flower stem
    var stemHeight: CGFloat {
        switch self {
        case .empty, .seed: return 0
        case .sprout: return 0.3
        case .budding: return 0.6
        case .blooming: return 0.85
        case .fullBloom: return 1.0
        }
    }

    /// Size scale for the flower head
    var flowerScale: CGFloat {
        switch self {
        case .empty, .seed: return 0.3
        case .sprout: return 0.4
        case .budding: return 0.6
        case .blooming: return 0.85
        case .fullBloom: return 1.0
        }
    }

    /// Whether this state shows petals
    var hasPetals: Bool {
        self == .blooming || self == .fullBloom
    }

    /// Number of petals to show
    var petalCount: Int {
        switch self {
        case .blooming: return 4
        case .fullBloom: return 6
        default: return 0
        }
    }

    /// Whether the flower should sway gently
    var shouldAnimate: Bool {
        self == .blooming || self == .fullBloom
    }
}

// MARK: - Day Flower

/// Represents a single day's flower in the weekly garden
struct DayFlower: Codable, Identifiable {
    let date: String           // YYYY-MM-DD
    let dayOfWeek: String      // "Mon", "Tue", etc.
    var bloomState: BloomState
    var checkInsCompleted: Int
    var tasksCompleted: Int
    var totalTasks: Int
    var isToday: Bool

    var id: String { date }

    /// Single-letter day label for compact display
    var dayLetter: String {
        String(dayOfWeek.prefix(1))
    }

    /// Progress percentage toward full bloom
    var progress: Double {
        let checkInProgress = Double(checkInsCompleted) / 3.0
        let taskProgress = totalTasks > 0 ? Double(tasksCompleted) / Double(totalTasks) : 1.0
        return (checkInProgress * 0.7) + (taskProgress * 0.3)
    }

    /// Flower color varies by day of week for visual variety
    var flowerColor: Color {
        let colors: [Color] = [
            Color(red: 1.0, green: 0.6, blue: 0.7),  // Mon - Pink
            Color(red: 0.8, green: 0.6, blue: 1.0),  // Tue - Purple
            Color(red: 1.0, green: 0.5, blue: 0.5),  // Wed - Red
            Color(red: 1.0, green: 0.7, blue: 0.4),  // Thu - Orange
            Color(red: 1.0, green: 0.9, blue: 0.4),  // Fri - Yellow
            Color(red: 0.6, green: 0.8, blue: 1.0),  // Sat - Blue
            Color(red: 0.6, green: 1.0, blue: 0.8),  // Sun - Mint
        ]
        let dayIndex = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].firstIndex(of: dayOfWeek) ?? 0
        return colors[dayIndex]
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case date
        case dayOfWeek
        case bloomState
        case checkInsCompleted
        case tasksCompleted
        case totalTasks
        case isToday
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        dayOfWeek = try container.decode(String.self, forKey: .dayOfWeek)
        let bloomRaw = try container.decode(Int.self, forKey: .bloomState)
        bloomState = BloomState(rawValue: bloomRaw) ?? .seed
        checkInsCompleted = try container.decode(Int.self, forKey: .checkInsCompleted)
        tasksCompleted = try container.decode(Int.self, forKey: .tasksCompleted)
        totalTasks = try container.decode(Int.self, forKey: .totalTasks)
        isToday = try container.decodeIfPresent(Bool.self, forKey: .isToday) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(dayOfWeek, forKey: .dayOfWeek)
        try container.encode(bloomState.rawValue, forKey: .bloomState)
        try container.encode(checkInsCompleted, forKey: .checkInsCompleted)
        try container.encode(tasksCompleted, forKey: .tasksCompleted)
        try container.encode(totalTasks, forKey: .totalTasks)
        try container.encode(isToday, forKey: .isToday)
    }

    init(
        date: String,
        dayOfWeek: String,
        bloomState: BloomState,
        checkInsCompleted: Int,
        tasksCompleted: Int,
        totalTasks: Int,
        isToday: Bool
    ) {
        self.date = date
        self.dayOfWeek = dayOfWeek
        self.bloomState = bloomState
        self.checkInsCompleted = checkInsCompleted
        self.tasksCompleted = tasksCompleted
        self.totalTasks = totalTasks
        self.isToday = isToday
    }
}

// MARK: - Weekly Garden

/// Represents the entire week's garden state
struct WeeklyGarden: Codable {
    let weekStartDate: String      // Monday's date YYYY-MM-DD
    var days: [DayFlower]          // 7 days Mon-Sun
    var currentStreak: Int
    var longestStreak: Int

    /// Check if all days in the week are fully bloomed
    var isPerfectWeek: Bool {
        days.allSatisfy { $0.bloomState == .fullBloom }
    }

    /// Number of blooming or full bloom days
    var bloomingDays: Int {
        days.filter { $0.bloomState == .blooming || $0.bloomState == .fullBloom }.count
    }

    /// Today's flower (if found)
    var todayFlower: DayFlower? {
        days.first { $0.isToday }
    }

    /// Calculate total check-ins completed this week
    var totalCheckInsThisWeek: Int {
        days.reduce(0) { $0 + $1.checkInsCompleted }
    }

    /// Calculate total tasks completed this week
    var totalTasksCompletedThisWeek: Int {
        days.reduce(0) { $0 + $1.tasksCompleted }
    }
}

// MARK: - Garden Manager

/// Observable object for managing garden state
@MainActor
class GardenManager: ObservableObject {
    static let shared = GardenManager()

    @Published var garden: WeeklyGarden?
    @Published var isLoading = false
    @Published var lastError: String?

    private init() {}

    /// Create an empty garden for the current week
    nonisolated static func createEmptyGarden() -> WeeklyGarden {
        let calendar = Calendar.current
        let today = Date()
        let todayString = formatDate(today)

        // Find Monday of this week
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2 // Monday
        let monday = calendar.date(from: components) ?? today

        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var days: [DayFlower] = []

        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: i, to: monday) ?? today
            let dateString = formatDate(date)
            let isFuture = dateString > todayString
            let isToday = dateString == todayString

            days.append(DayFlower(
                date: dateString,
                dayOfWeek: dayNames[i],
                bloomState: isFuture ? .empty : .seed,
                checkInsCompleted: 0,
                tasksCompleted: 0,
                totalTasks: 0,
                isToday: isToday
            ))
        }

        return WeeklyGarden(
            weekStartDate: formatDate(monday),
            days: days,
            currentStreak: 0,
            longestStreak: 0
        )
    }

    /// Format date as YYYY-MM-DD
    nonisolated private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Update a specific day's bloom state locally
    func updateDayBloom(date: String, checkInsCompleted: Int, tasksCompleted: Int, totalTasks: Int) {
        guard var garden = garden else { return }

        if let index = garden.days.firstIndex(where: { $0.date == date }) {
            garden.days[index].checkInsCompleted = checkInsCompleted
            garden.days[index].tasksCompleted = tasksCompleted
            garden.days[index].totalTasks = totalTasks

            // Calculate bloom state
            let isFuture = garden.days[index].date > GardenManager.formatDate(Date())
            if isFuture {
                garden.days[index].bloomState = .empty
            } else if checkInsCompleted == 0 {
                garden.days[index].bloomState = .seed
            } else if checkInsCompleted == 1 {
                garden.days[index].bloomState = .sprout
            } else if checkInsCompleted == 2 {
                garden.days[index].bloomState = .budding
            } else if checkInsCompleted >= 3 {
                if totalTasks == 0 || tasksCompleted >= totalTasks {
                    garden.days[index].bloomState = .fullBloom
                } else {
                    garden.days[index].bloomState = .blooming
                }
            }

            self.garden = garden
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension WeeklyGarden {
    static var preview: WeeklyGarden {
        var garden = GardenManager.createEmptyGarden()

        // Simulate some progress
        if garden.days.count >= 7 {
            garden.days[0].bloomState = .fullBloom
            garden.days[0].checkInsCompleted = 3
            garden.days[1].bloomState = .blooming
            garden.days[1].checkInsCompleted = 3
            garden.days[2].bloomState = .budding
            garden.days[2].checkInsCompleted = 2
            garden.days[3].bloomState = .sprout
            garden.days[3].checkInsCompleted = 1
        }

        garden.currentStreak = 3
        garden.longestStreak = 7

        return garden
    }
}

extension DayFlower {
    static var preview: DayFlower {
        DayFlower(
            date: "2024-12-23",
            dayOfWeek: "Mon",
            bloomState: .blooming,
            checkInsCompleted: 3,
            tasksCompleted: 2,
            totalTasks: 3,
            isToday: true
        )
    }
}
#endif
