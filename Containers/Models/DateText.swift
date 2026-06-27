import Foundation

nonisolated enum DateText {
    static func date(_ iso: String) -> Date? {
        try? Date(iso, strategy: .iso8601)
    }

    static func relative(_ iso: String) -> String {
        guard let parsed = date(iso) else { return iso }
        return parsed.formatted(.relative(presentation: .named))
    }

    static func uptime(since iso: String) -> String? {
        guard let parsed = date(iso) else { return nil }
        let interval = max(0, Date.now.timeIntervalSince(parsed))
        return Duration.seconds(interval).formatted(
            .units(allowed: [.days, .hours, .minutes, .seconds], width: .wide, maximumUnitCount: 1)
        )
    }
}
