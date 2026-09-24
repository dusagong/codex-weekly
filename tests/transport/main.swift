import Foundation
import Darwin

func send(_ value: Any) {
    let data = try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([10]))
}

func readMessage() -> [String: Any] {
    guard let line = readLine(), let data = line.data(using: .utf8),
          let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { exit(91) }
    return value
}

if CommandLine.arguments.contains("app-server") {
    let environment = ProcessInfo.processInfo.environment
    guard CommandLine.arguments.suffix(3) == ["app-server", "--listen", "stdio://"],
          (environment["PATH"] ?? "").split(separator: ":").contains("/opt/homebrew/bin") else { exit(92) }
    if let pidPath = environment["CODEX_USAGE_RPC_TEST_PID"] {
        try! String(getpid()).write(toFile: pidPath, atomically: true, encoding: .utf8)
    }
    signal(SIGTERM, SIG_IGN)
    let mode = environment["CODEX_USAGE_RPC_TEST_MODE"] ?? "success"
    if mode == "timeout" { while true { pause() } }
    if mode == "oversize" {
        FileHandle.standardOutput.write(Data(repeating: 120, count: 1_048_577))
        while true { pause() }
    }
    let initialize = readMessage()
    guard initialize["method"] as? String == "initialize",
          let initializationParams = initialize["params"] as? [String: Any],
          let client = initializationParams["clientInfo"] as? [String: Any],
          client["name"] as? String != nil, client["version"] as? String != nil else { exit(93) }
    if mode == "malformed" {
        FileHandle.standardOutput.write(Data("not json\n".utf8))
        while true { pause() }
    }
    if mode == "eof" { exit(0) }
    send(["method": "progress", "params": ["value": 1]])
    send(["id": "server-request", "method": "unknown/test", "params": [:]])
    let rejection = readMessage()
    guard rejection["id"] as? String == "server-request",
          (rejection["error"] as? [String: Any])?["code"] as? Int == -32601 else { exit(94) }
    send(["id": initialize["id"]!, "result": ["userAgent": "fixture"]])
    let initialized = readMessage()
    guard initialized["method"] as? String == "initialized", initialized["id"] == nil,
          (initialized["params"] as? [String: Any])?.isEmpty == true else { exit(95) }
    let request = readMessage()
    guard request["method"] as? String == "account/rateLimits/read" else { exit(96) }
    if mode == "server-error" {
        send(["id": request["id"]!, "error": ["code": -32000, "message": "SECRET_FAKE_TOKEN_SHOULD_NEVER_LEAK"]])
    } else {
        let response: [String: Any] = ["id": request["id"]!, "result": ["rateLimitsByLimitId": ["codex": ["primary": ["usedPercent": 37, "windowDurationMins": 10080, "resetsAt": 1800000000]]]]]
        let data = try! JSONSerialization.data(withJSONObject: response)
        FileHandle.standardOutput.write(data.prefix(17))
        usleep(10_000)
        FileHandle.standardOutput.write(data.dropFirst(17))
        FileHandle.standardOutput.write(Data([10]))
    }
    if mode == "graceful" {
        guard readLine() == nil else { exit(97) }
        if let path = environment["CODEX_USAGE_RPC_TEST_PID"] {
            try! "eof".write(toFile: path + "-graceful", atomically: true, encoding: .utf8)
        }
        exit(0)
    }
    while true { pause() }
}

var failures = 0
let root = FileManager.default.temporaryDirectory.appendingPathComponent("codex-weekly-transport-\(UUID().uuidString)", isDirectory: true)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
let executable = URL(fileURLWithPath: CommandLine.arguments[0], relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).standardizedFileURL

@MainActor func check(_ condition: @autoclosure () -> Bool, _ description: String) {
    if condition() { print("PASS \(description)") } else { print("FAIL \(description)"); failures += 1 }
}

for mode in ["success", "graceful", "server-error", "timeout", "oversize", "malformed", "eof"] {
    let pidURL = root.appendingPathComponent("\(mode).pid")
    try? FileManager.default.removeItem(at: pidURL)
    setenv("CODEX_USAGE_RPC_TEST_MODE", mode, 1)
    setenv("CODEX_USAGE_RPC_TEST_PID", pidURL.path, 1)
    let start = ProcessInfo.processInfo.systemUptime
    do {
        let data = try UsageRPC.fetch(executableURL: executable, timeout: mode == "timeout" ? 0.3 : 2)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let bucket = (object?["rateLimitsByLimitId"] as? [String: Any])?["codex"] as? [String: Any]
        check(["success", "graceful"].contains(mode) && (bucket?["primary"] as? [String: Any])?["usedPercent"] as? Int == 37, "\(mode): returns result only after handshake")
    } catch {
        check(!["success", "graceful"].contains(mode), "\(mode): expected transport outcome (\(error.localizedDescription))")
        check(!error.localizedDescription.contains("SECRET_FAKE_TOKEN"), "\(mode): does not reveal server error data")
    }
    let elapsed = ProcessInfo.processInfo.systemUptime - start
    check(elapsed < (mode == "timeout" ? 0.6 : 2.3), "\(mode): bounded duration")
    if let pidString = try? String(contentsOf: pidURL, encoding: .utf8), let pid = Int32(pidString) {
        check(kill(pid, 0) == -1 && errno == ESRCH, "\(mode): child reaped")
    } else {
        check(false, "\(mode): child fixture ran")
    }
    if mode == "graceful" {
        check(FileManager.default.fileExists(atPath: pidURL.path + "-graceful"), "graceful: child completed shutdown after stdin EOF")
        try? FileManager.default.removeItem(atPath: pidURL.path + "-graceful")
    }
    try? FileManager.default.removeItem(at: pidURL)
}

check((try? UsageRPC.fetch(executableURL: URL(fileURLWithPath: "/does/not/exist"), timeout: 0.2)) == nil, "missing executable fails")
print("\(failures) failure(s)")
exit(failures == 0 ? 0 : 1)
