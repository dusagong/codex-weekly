import Foundation

var checks = 0
var failures = 0
func check(_ condition: @autoclosure () -> Bool, _ label: String) {
    checks += 1
    if !condition() { failures += 1; print("FAIL: \(label)") }
}
let now = Date(timeIntervalSince1970: 1_800_000_000)
let reset = now.addingTimeInterval(604_800 * 0.4)
func comparison(used: Double, reset: Date? = reset, stale: Bool = false) -> UsageComparison {
    UsageComparison(usage: WeeklyUsage(usedPercent: used, resetsAt: reset, fetchedAt: now), at: now, isStale: stale)
}
let ahead = comparison(used: 30)
check(ahead.timeRemainingPercent == 40, "forty percent of the week remains")
check(ahead.differencePercentagePoints == 30, "allowance ahead by thirty percentage points")
check(ahead.pace == .ahead, "positive difference is ahead")
check(ahead.timeText.contains("40.0%"), "time percentage is labeled")
check(ahead.paceText.contains("30.0%p"), "gap uses percentage points")
let behind = comparison(used: 80)
check(behind.differencePercentagePoints == -20, "negative difference retained")
check(behind.pace == .behind, "negative difference is behind")
check(behind.paceText.contains("20.0%p"), "behind magnitude shown without confusing double negative")
check(comparison(used: 60).pace == .balanced, "equal fractions are balanced")
check(comparison(used: 59.99).pace == .balanced, "sub-display precision difference is balanced")
let stale = comparison(used: 30, stale: true)
check(stale.timeRemainingPercent == 40, "clock still available for stale allowance")
check(stale.differencePercentagePoints == nil, "stale reading has no pace judgment")
check(stale.pace == .stale, "stale reading prompts refresh")
let missingReset = comparison(used: 30, reset: nil)
check(missingReset.timeRemainingPercent == nil, "missing reset is unknown, not zero")
check(missingReset.differencePercentagePoints == nil, "missing reset cannot compare")
check(missingReset.pace == .unavailable, "missing reset unavailable")
let expired = comparison(used: 30, reset: now)
check(expired.timeRemainingPercent == 0, "reset reached shows zero time")
check(expired.differencePercentagePoints == nil, "expired quota must not be compared")
check(expired.pace == .unavailable, "expired quota unavailable")
let absent = UsageComparison(usage: nil, at: now, isStale: false)
check(absent.timeRemainingPercent == nil && absent.differencePercentagePoints == nil, "no reading has no comparison")
check(UsageComparison.durationText(60 * 60 * 24 * 2 + 60 * 60 * 19) == "2일 19시간", "days and hours countdown")
check(UsageComparison.durationText(3 * 3600 + 12 * 60) == "3시간 12분", "hours and minutes countdown")
check(UsageComparison.durationText(8 * 60) == "8분", "minutes countdown")
check(UsageComparison.durationText(30) == "1분 미만", "positive seconds must not show zero minutes")
print("\(checks) comparison checks; \(failures) failures")
exit(failures == 0 ? 0 : 1)
