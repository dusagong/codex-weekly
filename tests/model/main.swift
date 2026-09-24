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

print("\(checks) checks; \(failures) failures")
exit(failures == 0 ? 0 : 1)
