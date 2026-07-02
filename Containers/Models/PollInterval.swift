import Foundation

nonisolated enum PollInterval: String, CaseIterable, Identifiable, Sendable {
    case fast
    case standard
    case relaxed

    var id: String { rawValue }

    var containers: Duration {
        switch self {
        case .fast: .seconds(1.5)
        case .standard: .seconds(3)
        case .relaxed: .seconds(5)
        }
    }

    var secondary: Duration {
        containers + .seconds(1)
    }

    var images: Duration {
        containers + .seconds(2)
    }

    static func current(from defaults: UserDefaults = .standard) -> PollInterval {
        PollInterval(rawValue: defaults.string(forKey: "pollInterval") ?? "") ?? .standard
    }
}
