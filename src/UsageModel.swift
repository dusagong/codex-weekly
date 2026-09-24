import Foundation

struct WeeklyUsage: Equatable {
    let usedPercent: Double
    let resetsAt: Date?
    let fetchedAt: Date

    var remainingPercent: Double { max(0, min(100, 100 - usedPercent)) }
    var remainingText: String { "\(Int(remainingPercent.rounded(.down)))%" }
    var usedText: String { "\(Int(max(0, min(100, usedPercent)).rounded(.up)))%" }

    func isExpired(at now: Date = Date()) -> Bool {
        resetsAt.map { $0 <= now } ?? false
    }
}

enum UsageModelError: LocalizedError {
    case invalidResponse
    case noCodexBucket
    case weeklyUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Codex 사용량 응답을 읽지 못했습니다."
        case .noCodexBucket: return "계정의 Codex 공통 사용 한도를 찾지 못했습니다."
        case .weeklyUnavailable: return "주간 사용 한도가 제공되지 않았습니다. Codex 로그인 상태를 확인해 주세요."
        }
    }
}

enum UsageModel {
    private struct Window: Decodable {
        let usedPercent: Double?
        let windowDurationMins: Int?
        let resetsAt: Double?
    }
    private struct Snapshot: Decodable {
        let limitId: String?
        let primary: Window?
        let secondary: Window?
    }
    private struct Response: Decodable {
        let rateLimits: Snapshot?
        let rateLimitsByLimitId: [String: Snapshot]?
    }

    static func parse(_ data: Data, fetchedAt: Date = Date()) throws -> WeeklyUsage {
        let response: Response
        do { response = try JSONDecoder().decode(Response.self, from: data) }
        catch { throw UsageModelError.invalidResponse }

        let snapshot: Snapshot
        if let buckets = response.rateLimitsByLimitId, !buckets.isEmpty {
            guard let codex = buckets["codex"] ?? buckets.values.first(where: { $0.limitId == "codex" }) else {
                throw UsageModelError.noCodexBucket
            }
            snapshot = codex
        } else {
            guard let legacy = response.rateLimits,
                  legacy.limitId == nil || legacy.limitId == "codex" else {
                throw UsageModelError.noCodexBucket
            }
            snapshot = legacy
        }

        guard let weekly = [snapshot.primary, snapshot.secondary].compactMap({ $0 }).first(where: { $0.windowDurationMins == 10_080 }),
              let used = weekly.usedPercent, used.isFinite else {
            throw UsageModelError.weeklyUnavailable
        }
        let reset = weekly.resetsAt.flatMap { value -> Date? in
            guard value.isFinite, value > 0 else { return nil }
            return Date(timeIntervalSince1970: value)
        }
        return WeeklyUsage(usedPercent: used, resetsAt: reset, fetchedAt: fetchedAt)
    }
}
