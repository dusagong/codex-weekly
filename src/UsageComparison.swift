import Foundation

/// Shared text and state for the menu, tooltip, and details window.
struct UsageComparison {
    enum Pace: Equatable { case ahead, behind, balanced, stale, unavailable }
    let timeRemainingPercent: Double?
    let differencePercentagePoints: Double?
    let timeText: String
    let paceText: String
    let pace: Pace

    init(usage: WeeklyUsage?, at now: Date, isStale: Bool) {
        guard let usage,
              let percent = usage.timeRemainingPercent(at: now),
              let reset = usage.resetsAt else {
            timeRemainingPercent = nil
            differencePercentagePoints = nil
            timeText = "주간 시간: 초기화 시각 정보 없음"
            paceText = "초기화 시각을 확인하면 비교할 수 있습니다"
            pace = .unavailable
            return
        }
        timeRemainingPercent = percent
        if usage.isExpired(at: now) {
            timeText = "주간 시간 0.0% · 초기화 시각 지남"
            differencePercentagePoints = nil
            paceText = "새 주간 사용량을 확인한 뒤 비교합니다"
            pace = .unavailable
            return
        }
        timeText = "주간 시간 \(Self.percentText(percent)) 남음 · \(Self.durationText(reset.timeIntervalSince(now)))"
        guard !isStale, let comparison = usage.pace(at: now) else {
            differencePercentagePoints = nil
            paceText = "최신 사용량 확인 후 비교합니다"
            pace = .stale
            return
        }
        let difference = comparison.differencePercentagePoints
        differencePercentagePoints = difference
        // Classify at the displayed precision so a 0.0-point gap is neutral.
        let rounded = (difference * 10).rounded() / 10
        if rounded > 0 {
            paceText = "균등 사용 기준보다 \(Self.pointsText(rounded)) 여유"
            pace = .ahead
        } else if rounded < 0 {
            paceText = "균등 사용 기준보다 \(Self.pointsText(-rounded)) 더 사용"
            pace = .behind
        } else {
            paceText = "균등 사용 기준과 비슷합니다 · 차이 0.0%p"
            pace = .balanced
        }
    }

    static func percentText(_ value: Double) -> String {
        String(format: "%.1f%%", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func pointsText(_ value: Double) -> String {
        String(format: "%.1f%%p", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    static func durationText(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0분" }
        let minutes = Int(min(seconds / 60, Double(Int.max / 2)))
        let days = minutes / (24 * 60)
        let hours = (minutes / 60) % 24
        if days > 0 { return "\(days)일 \(hours)시간" }
        if hours > 0 { return "\(hours)시간 \(minutes % 60)분" }
        if minutes > 0 { return "\(minutes)분" }
        return "1분 미만"
    }
}
