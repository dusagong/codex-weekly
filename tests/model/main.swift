import Foundation

var checks = 0
var failures = 0

func check(_ condition: @autoclosure () -> Bool, _ label: String) {
    checks += 1
    if !condition() {
        failures += 1
        print("FAIL: \(label)")
    }
}

func parse(_ json: String) throws -> WeeklyUsage {
    try UsageModel.parse(Data(json.utf8), fetchedAt: Date(timeIntervalSince1970: 1_000))
}

func rejects(_ json: String, _ expected: UsageModelError, _ label: String) {
    do {
        _ = try parse(json)
        check(false, label + " accepted unavailable data")
    } catch let error as UsageModelError {
        check(String(describing: error) == String(describing: expected), label + " error classification")
    } catch {
        check(false, label + " unexpected error: \(error)")
    }
}

do {
    let primary = try parse(#"{"rateLimits":{"primary":{"windowDurationMins":10080,"usedPercent":37.5,"resetsAt":2000}}}"#)
    check(primary.remainingPercent == 62.5, "primary weekly remaining")
    check(primary.remainingText == "62%", "remaining floors conservatively")
    check(primary.usedText == "38%", "used rounds up conservatively")
    check(primary.fetchedAt == Date(timeIntervalSince1970: 1_000), "fetch timestamp preserved")
    check(primary.resetsAt == Date(timeIntervalSince1970: 2_000), "reset uses Unix seconds")
    check(!primary.isExpired(at: Date(timeIntervalSince1970: 1_999)), "not expired before reset")
    check(primary.isExpired(at: Date(timeIntervalSince1970: 2_000)), "expired at exact reset")
    check(primary.isExpired(at: Date(timeIntervalSince1970: 2_001)), "expired after reset")

    let secondary = try parse(#"{"rateLimits":{"limitId":"codex","primary":{"windowDurationMins":300,"usedPercent":95},"secondary":{"windowDurationMins":10080,"usedPercent":12}}}"#)
    check(secondary.remainingPercent == 88, "secondary weekly ignores short window")

    let modern = try parse(#"{"rateLimits":{"secondary":{"windowDurationMins":10080,"usedPercent":99}},"rateLimitsByLimitId":{"codex":{"secondary":{"windowDurationMins":10080,"usedPercent":18}},"special":{"limitId":"special","primary":{"windowDurationMins":10080,"usedPercent":2}}}}"#)
    check(modern.remainingPercent == 82, "modern Codex bucket wins legacy conflict")

    let namedSnapshot = try parse(#"{"rateLimitsByLimitId":{"shared":{"limitId":"codex","primary":{"windowDurationMins":10080,"usedPercent":25}}}}"#)
    check(namedSnapshot.remainingPercent == 75, "Codex limitId recognized when map key differs")

    let emptyMap = try parse(#"{"rateLimitsByLimitId":{},"rateLimits":{"secondary":{"windowDurationMins":10080,"usedPercent":30}}}"#)
    check(emptyMap.remainingPercent == 70, "empty modern map permits legacy fallback")

    for (used, remaining) in [(-20.0, 100.0), (0.0, 100.0), (100.0, 0.0), (125.0, 0.0)] {
        let value = try parse("{\"rateLimits\":{\"primary\":{\"windowDurationMins\":10080,\"usedPercent\":\(used)}}}")
        check(value.remainingPercent == remaining, "clamping remaining for \(used)")
        check(value.remainingText == "\(Int(remaining))%", "clamping displayed remaining for \(used)")
        check(value.usedText == "\(Int(100 - remaining))%", "clamping displayed used for \(used)")
    }

    for resetField in ["", ",\"resetsAt\":null", ",\"resetsAt\":0", ",\"resetsAt\":-1"] {
        let value = try parse("{\"rateLimits\":{\"primary\":{\"windowDurationMins\":10080,\"usedPercent\":12\(resetField)}}}")
        check(value.resetsAt == nil, "missing or invalid reset unavailable: \(resetField)")
        check(!value.isExpired(at: Date(timeIntervalSince1970: 9_999_999)), "unknown reset not inferred expired: \(resetField)")
    }
} catch {
    check(false, "valid fixture unexpectedly rejected: \(error)")
}

rejects(#"{"rateLimitsByLimitId":{"model-only":{"primary":{"windowDurationMins":10080,"usedPercent":12}}},"rateLimits":{"secondary":{"windowDurationMins":10080,"usedPercent":50}}}"#, .noCodexBucket, "unknown modern bucket does not use misleading legacy fallback")
rejects(#"{"rateLimits":{"limitId":"non-codex","primary":{"windowDurationMins":10080,"usedPercent":12}}}"#, .noCodexBucket, "unknown legacy bucket unavailable")
rejects(#"{}"#, .noCodexBucket, "absent rate limits unavailable")
rejects(#"{"rateLimits":null,"rateLimitsByLimitId":null}"#, .noCodexBucket, "null rate limits unavailable")
rejects(#"{"rateLimits":{"primary":null,"secondary":null}}"#, .weeklyUnavailable, "null windows unavailable")
rejects(#"{"rateLimits":{"primary":{"windowDurationMins":10080,"usedPercent":null}}}"#, .weeklyUnavailable, "null used percent unavailable")
rejects(#"{"rateLimits":{"primary":{"windowDurationMins":10080}}}"#, .weeklyUnavailable, "missing used percent unavailable")
rejects(#"{"rateLimits":{"primary":{"usedPercent":0}}}"#, .weeklyUnavailable, "missing duration unavailable")
rejects(#"{"rateLimits":{"primary":{"windowDurationMins":null,"usedPercent":0}}}"#, .weeklyUnavailable, "null duration unavailable")
rejects(#"{"rateLimits":{"primary":{"windowDurationMins":300,"usedPercent":0}}}"#, .weeklyUnavailable, "short window not weekly")
rejects(#"{"rateLimitsByLimitId":{"codex":{"primary":{"windowDurationMins":10080,"usedPercent":null}}},"rateLimits":{"secondary":{"windowDurationMins":10080,"usedPercent":50}}}"#, .weeklyUnavailable, "modern unavailable value not replaced with legacy")
rejects("this is not JSON", .invalidResponse, "invalid JSON rejected")
rejects(#"{"rateLimits":{"primary":{"windowDurationMins":10080,"usedPercent":"0"}}}"#, .invalidResponse, "invalid numeric type rejected")

func approximately(_ actual: Double?, _ expected: Double, tolerance: Double = 0.000_000_001) -> Bool {
    guard let actual else { return false }
    return abs(actual - expected) <= tolerance
}

let week: TimeInterval = 604_800
let cycleStart = Date(timeIntervalSince1970: 1_800_000_000)
let cycleEnd = cycleStart.addingTimeInterval(week)
let halfway = cycleStart.addingTimeInterval(week / 2)
let balancedUsage = WeeklyUsage(usedPercent: 50, resetsAt: cycleEnd, fetchedAt: cycleStart)

check(WeeklyUsage.windowDuration == week, "week is exactly 604800 seconds")
check(balancedUsage.timeRemainingPercent(at: cycleStart) == 100, "full weekly time remains at cycle start")
check(balancedUsage.timeRemainingPercent(at: halfway) == 50, "half weekly time remains at midpoint")
check(balancedUsage.timeRemainingPercent(at: cycleEnd) == 0, "no weekly time remains at reset")
check(balancedUsage.timeRemainingPercent(at: cycleEnd.addingTimeInterval(1)) == 0, "expired time clamps to zero")
check(approximately(balancedUsage.timeRemainingPercent(at: halfway.addingTimeInterval(1)), 50 - 100 / week), "time percentage decreases each second")
check(approximately(balancedUsage.timeRemainingPercent(at: halfway.addingTimeInterval(0.5)), 50 - 50 / week), "subsecond time percentage is not quantized to days")
check(balancedUsage.pace(at: cycleEnd) == nil, "pace unavailable at exact reset")
check(balancedUsage.pace(at: cycleEnd.addingTimeInterval(1)) == nil, "pace unavailable after reset")
check(balancedUsage.pace(at: halfway)?.timeRemainingPercent == 50, "pace includes remaining time percentage")
check(balancedUsage.pace(at: halfway)?.secondsRemaining == week / 2, "pace includes remaining seconds")
check(balancedUsage.pace(at: halfway)?.differencePercentagePoints == 0, "equal quota and time gives zero difference")

let higherQuota = WeeklyUsage(usedPercent: 25, resetsAt: cycleEnd, fetchedAt: cycleStart)
let lowerQuota = WeeklyUsage(usedPercent: 75, resetsAt: cycleEnd, fetchedAt: cycleStart)
check(higherQuota.pace(at: halfway)?.differencePercentagePoints == 25, "more quota than time gives positive percentage-point difference")
check(lowerQuota.pace(at: halfway)?.differencePercentagePoints == -25, "less quota than time gives negative percentage-point difference")
check(higherQuota.pace(at: cycleStart)?.differencePercentagePoints == -25, "pace at cycle start compares against 100 percent time")
check(balancedUsage.pace(at: cycleEnd.addingTimeInterval(-1))?.secondsRemaining == 1, "pace retains final positive second")

let unknownReset = WeeklyUsage(usedPercent: 50, resetsAt: nil, fetchedAt: cycleStart)
check(unknownReset.timeRemainingPercent(at: halfway) == nil, "unknown reset gives no time percentage")
check(unknownReset.pace(at: halfway) == nil, "unknown reset gives no pace")

for (used, expectedDifference) in [(-20.0, 50.0), (0.0, 50.0), (100.0, -50.0), (125.0, -50.0)] {
    let usage = WeeklyUsage(usedPercent: used, resetsAt: cycleEnd, fetchedAt: cycleStart)
    check(usage.pace(at: halfway)?.differencePercentagePoints == expectedDifference, "pace uses clamped quota for used percentage \(used)")
}

let farReset = WeeklyUsage(usedPercent: 10, resetsAt: cycleStart.addingTimeInterval(2 * week), fetchedAt: cycleStart)
check(farReset.timeRemainingPercent(at: cycleStart) == 100, "reset beyond one week clamps time to 100 percent")
check(farReset.pace(at: cycleStart)?.timeRemainingPercent == 100, "pace uses clamped future time percentage")
check(farReset.pace(at: cycleStart)?.secondsRemaining == 2 * week, "pace preserves actual seconds beyond one week")
check(farReset.pace(at: cycleStart)?.differencePercentagePoints == -10, "far future reset compares quota to clamped 100 percent")

let isoDate = ISO8601DateFormatter()
let beforeDST = isoDate.date(from: "2026-03-08T01:30:00-08:00")!
let sameInstantUTC = isoDate.date(from: "2026-03-08T09:30:00Z")!
let nextLocalSunday = isoDate.date(from: "2026-03-15T01:30:00-07:00")!
let dstUsage = WeeklyUsage(usedPercent: 10, resetsAt: nextLocalSunday, fetchedAt: beforeDST)
check(dstUsage.pace(at: beforeDST)?.secondsRemaining == 167 * 3_600, "spring DST boundary uses 167 elapsed hours")
check(approximately(dstUsage.timeRemainingPercent(at: beforeDST), 167.0 / 168 * 100), "DST boundary uses fixed 168-hour window")
check(dstUsage.pace(at: beforeDST) == dstUsage.pace(at: sameInstantUTC), "same instant in different timezones gives same pace")

for invalidTime in [TimeInterval.nan, .infinity, -.infinity] {
    let invalidDate = Date(timeIntervalSince1970: invalidTime)
    let invalidReset = WeeklyUsage(usedPercent: 50, resetsAt: invalidDate, fetchedAt: cycleStart)
    check(invalidReset.timeRemainingPercent(at: halfway) == nil, "nonfinite reset gives no time percentage: \(invalidTime)")
    check(invalidReset.pace(at: halfway) == nil, "nonfinite reset gives no pace: \(invalidTime)")
    check(balancedUsage.timeRemainingPercent(at: invalidDate) == nil, "nonfinite current time gives no time percentage: \(invalidTime)")
    check(balancedUsage.pace(at: invalidDate) == nil, "nonfinite current time gives no pace: \(invalidTime)")
}

print("\(checks) checks; \(failures) failures")
exit(failures == 0 ? 0 : 1)
