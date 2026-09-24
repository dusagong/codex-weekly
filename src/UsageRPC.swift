import Foundation
import Darwin

public enum UsageRPC {
    /// A synchronous, bounded read. Call from a background queue, never the AppKit main queue.
    public static func fetch(executableURL: URL, timeout: TimeInterval = 25) throws -> Data {
        guard timeout.isFinite, timeout > 0 else { throw TransportError.timedOut }
        guard executableURL.isFileURL,
              FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw TransportError.executableMissing
        }
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var input = [Int32](repeating: -1, count: 2)
        var output = [Int32](repeating: -1, count: 2)
        guard pipe(&input) == 0 else { throw TransportError.launchFailed }
        defer { for descriptor in input where descriptor >= 0 { close(descriptor) } }
        guard pipe(&output) == 0 else { throw TransportError.launchFailed }
        defer { for descriptor in output where descriptor >= 0 { close(descriptor) } }
        let nullDescriptor = open("/dev/null", O_WRONLY | O_CLOEXEC)
        guard nullDescriptor >= 0 else { throw TransportError.launchFailed }
        defer { close(nullDescriptor) }

        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else { throw TransportError.launchFailed }
        defer { posix_spawn_file_actions_destroy(&actions) }
        guard posix_spawnattr_init(&attributes) == 0 else { throw TransportError.launchFailed }
        defer { posix_spawnattr_destroy(&attributes) }
        let preparationResults = [
            posix_spawn_file_actions_adddup2(&actions, input[0], STDIN_FILENO),
            posix_spawn_file_actions_adddup2(&actions, output[1], STDOUT_FILENO),
            posix_spawn_file_actions_adddup2(&actions, nullDescriptor, STDERR_FILENO),
            posix_spawnattr_setpgroup(&attributes, 0),
            posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT))
        ]
        guard preparationResults.allSatisfy({ $0 == 0 }) else { throw TransportError.launchFailed }

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
        let argumentValues: [String] = [executableURL.path, "app-server", "--listen", "stdio://"]
        var arguments: [UnsafeMutablePointer<CChar>?] = argumentValues.map { value in value.withCString { strdup($0) } } + [nil]
        var environmentStrings: [UnsafeMutablePointer<CChar>?] = environment.map { pair in "\(pair.key)=\(pair.value)".withCString { strdup($0) } } + [nil]
        defer {
            for value in arguments { free(value) }
            for value in environmentStrings { free(value) }
        }
        var pid: pid_t = 0
        let launchResult = arguments.withUnsafeMutableBufferPointer { argv in
            environmentStrings.withUnsafeMutableBufferPointer { envp in
                posix_spawn(&pid, executableURL.path, &actions, &attributes, argv.baseAddress!, envp.baseAddress!)
            }
        }
        guard launchResult == 0 else { throw TransportError.launchFailed }
        defer {
            if input[1] >= 0 { close(input[1]); input[1] = -1 }
            finishChild(pid)
        }
        close(input[0]); input[0] = -1
        close(output[1]); output[1] = -1
        guard fcntl(input[1], F_SETFL, fcntl(input[1], F_GETFL) | O_NONBLOCK) != -1,
              fcntl(output[0], F_SETFL, fcntl(output[0], F_GETFL) | O_NONBLOCK) != -1,
              fcntl(input[1], F_SETNOSIGPIPE, 1) != -1 else { throw TransportError.launchFailed }

        func send(_ message: [String: Any]) throws {
            guard var data = try? JSONSerialization.data(withJSONObject: message) else { throw TransportError.invalidResponse }
            data.append(10)
            try data.withUnsafeBytes { bytes in
                var offset = 0
                while offset < bytes.count {
                    try waitFor(input[1], events: Int16(POLLOUT), deadline: deadline)
                    let written = Darwin.write(input[1], bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                    if written > 0 { offset += written }
                    else if written == -1 && (errno == EAGAIN || errno == EINTR) { continue }
                    else { throw TransportError.connectionClosed }
                }
            }
        }

        try send([
            "id": 0,
            "method": "initialize",
            "params": ["clientInfo": ["name": "codex_weekly_menu", "title": "Codex Weekly Menu", "version": "1.0.0"]]
        ])
        var initialized = false
        var pending = Data()
        var totalBytes = 0
        var chunk = [UInt8](repeating: 0, count: 16_384)
        while true {
            try waitFor(output[0], events: Int16(POLLIN), deadline: deadline)
            let count = Darwin.read(output[0], &chunk, chunk.count)
            if count == -1 && (errno == EAGAIN || errno == EINTR) { continue }
            guard count > 0 else { throw TransportError.connectionClosed }
            totalBytes += count
            guard totalBytes <= 1_048_576 else { throw TransportError.outputTooLarge }
            pending.append(contentsOf: chunk.prefix(count))
            while let newline = pending.firstIndex(of: 10) {
                guard ProcessInfo.processInfo.systemUptime < deadline else { throw TransportError.timedOut }
                let line = pending.subdata(in: pending.startIndex..<newline)
                pending.removeSubrange(pending.startIndex...newline)
                if line.isEmpty { continue }
                guard let message = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] else {
                    throw TransportError.invalidResponse
                }
                if message["method"] is String {
                    // Notifications are irrelevant. Never carry out a server-initiated action.
                    if let requestID = message["id"] {
                        try send(["id": requestID, "error": ["code": -32601, "message": "Method not supported"]])
                    }
                    continue
                }
                guard let id = message["id"] as? Int, id == (initialized ? 1 : 0) else { continue }
                if message["error"] != nil { throw TransportError.serverRejected }
                guard let result = message["result"] as? [String: Any] else { throw TransportError.invalidResponse }
                if !initialized {
                    try send(["method": "initialized", "params": [String: Any]()])
                    try send(["id": 1, "method": "account/rateLimits/read"])
                    initialized = true
                } else {
                    guard let data = try? JSONSerialization.data(withJSONObject: result) else { throw TransportError.invalidResponse }
                    return data
                }
            }
        }
    }

    private static func finishChild(_ pid: pid_t) {
        // EOF lets Codex finish pending state writes. Cleanup has a separate 250 ms grace period.
        let deadline = ProcessInfo.processInfo.systemUptime + 0.25
        var status: Int32 = 0
        while true {
            let result = waitpid(pid, &status, WNOHANG)
            // Once reaped, its PID may be reused. Never signal this PID or group again.
            if result == pid || (result == -1 && errno == ECHILD) { return }
            if ProcessInfo.processInfo.systemUptime >= deadline { break }
            usleep(5_000)
        }
        // posix_spawn created a private group whose ID equals the still-unreaped child PID.
        // Kill helpers with their parent when normal shutdown did not finish in time.
        kill(-pid, SIGKILL)
        kill(pid, SIGKILL)
        while waitpid(pid, &status, 0) == -1 && errno == EINTR {}
    }

    private static func waitFor(_ descriptor: Int32, events: Int16, deadline: TimeInterval) throws {
        while true {
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { throw TransportError.timedOut }
            var item = pollfd(fd: descriptor, events: events, revents: 0)
            let result = poll(&item, 1, Int32(min(100, remaining * 1_000)))
            if result == -1 && errno == EINTR { continue }
            guard result >= 0, item.revents & Int16(POLLNVAL) == 0 else { throw TransportError.connectionClosed }
            if result > 0 { return }
        }
    }

    private enum TransportError: LocalizedError {
        case executableMissing, launchFailed, timedOut, connectionClosed, invalidResponse, outputTooLarge, serverRejected

        var errorDescription: String? {
            switch self {
            case .executableMissing:
                return "Codex 실행 파일을 찾지 못했습니다. Codex 앱 설치 상태를 확인해 주세요."
            case .launchFailed:
                return "Codex 사용량 조회를 시작하지 못했습니다. 잠시 후 다시 시도해 주세요."
            case .timedOut:
                return "사용량 조회 시간이 초과됐습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요."
            case .connectionClosed:
                return "Codex 사용량 연결이 종료됐습니다. Codex 로그인 상태를 확인한 뒤 다시 시도해 주세요."
            case .invalidResponse, .outputTooLarge:
                return "Codex 사용량 응답을 읽지 못했습니다. Codex 앱을 업데이트한 뒤 다시 시도해 주세요."
            case .serverRejected:
                return "Codex에서 사용량을 가져오지 못했습니다. Codex 로그인 상태를 확인한 뒤 다시 시도해 주세요."
            }
        }
    }
}
