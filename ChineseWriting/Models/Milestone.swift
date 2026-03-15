import Foundation

/// Achievement milestones that trigger special celebrations.
enum MilestoneType: String, Codable {
    // Mastery count thresholds
    case mastery50, mastery100, mastery200, mastery500, mastery1000

    // Grade completion (all characters in grade mastered)
    case gradeComplete1, gradeComplete2, gradeComplete3, gradeComplete4
    case gradeComplete5, gradeComplete6, gradeComplete7

    // Streak thresholds
    case streak7, streak30, streak100

    static let masteryThresholds: [(count: Int, milestone: MilestoneType)] = [
        (50, .mastery50), (100, .mastery100), (200, .mastery200),
        (500, .mastery500), (1000, .mastery1000)
    ]

    static let streakThresholds: [(days: Int, milestone: MilestoneType)] = [
        (7, .streak7), (30, .streak30), (100, .streak100)
    ]

    static func gradeComplete(for grade: Int) -> MilestoneType? {
        switch grade {
        case 1: return .gradeComplete1
        case 2: return .gradeComplete2
        case 3: return .gradeComplete3
        case 4: return .gradeComplete4
        case 5: return .gradeComplete5
        case 6: return .gradeComplete6
        case 7: return .gradeComplete7
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .mastery50: return "50 Characters Mastered!"
        case .mastery100: return "100 Characters Mastered!"
        case .mastery200: return "200 Characters Mastered!"
        case .mastery500: return "500 Characters Mastered!"
        case .mastery1000: return "1,000 Characters Mastered!"
        case .gradeComplete1: return "Grade 1 Complete!"
        case .gradeComplete2: return "Grade 2 Complete!"
        case .gradeComplete3: return "Grade 3 Complete!"
        case .gradeComplete4: return "Grade 4 Complete!"
        case .gradeComplete5: return "Grade 5 Complete!"
        case .gradeComplete6: return "Grade 6 Complete!"
        case .gradeComplete7: return "Expansion Complete!"
        case .streak7: return "7-Day Streak!"
        case .streak30: return "30-Day Streak!"
        case .streak100: return "100-Day Streak!"
        }
    }

    var subtitle: String {
        switch self {
        case .mastery50: return "You're building a great foundation!"
        case .mastery100: return "Triple digits — amazing progress!"
        case .mastery200: return "You're reading more every day!"
        case .mastery500: return "Halfway to a thousand — incredible!"
        case .mastery1000: return "A true scholar in the making!"
        case .gradeComplete1, .gradeComplete2, .gradeComplete3:
            return "Every grade mastered is a big step!"
        case .gradeComplete4, .gradeComplete5, .gradeComplete6:
            return "You've come so far — keep it up!"
        case .gradeComplete7:
            return "You've mastered the entire expansion set!"
        case .streak7: return "A whole week of practice!"
        case .streak30: return "A month of dedication — wow!"
        case .streak100: return "100 days strong — unstoppable!"
        }
    }

    var icon: String {
        switch self {
        case .mastery50, .mastery100, .mastery200, .mastery500, .mastery1000:
            return "trophy.fill"
        case .gradeComplete1, .gradeComplete2, .gradeComplete3,
             .gradeComplete4, .gradeComplete5, .gradeComplete6, .gradeComplete7:
            return "graduationcap.fill"
        case .streak7, .streak30, .streak100:
            return "flame.fill"
        }
    }
}
