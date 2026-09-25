import AppKit

enum CodexLocation {
    static var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex")
            ?? ["/Applications/ChatGPT.app", "/Applications/Codex.app"]
                .first(where: { FileManager.default.fileExists(atPath: $0) })
                .map { URL(fileURLWithPath: $0) }
    }

    static func binaryURL() throws -> URL {
        var paths: [String] = []
        if let appURL { paths.append(appURL.appendingPathComponent("Contents/Resources/codex").path) }
        paths += ["/Applications/ChatGPT.app/Contents/Resources/codex", "/Applications/Codex.app/Contents/Resources/codex", "/opt/homebrew/bin/codex", "/usr/local/bin/codex"]
        guard let path = paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw NSError(domain: "CodexWeekly", code: 1, userInfo: [NSLocalizedDescriptionKey: "Codex 앱을 찾지 못했습니다. Codex를 설치하고 로그인해 주세요."])
        }
        return URL(fileURLWithPath: path)
    }
}

final class WeeklyApp: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let titleItem = NSMenuItem(title: "주간 사용량 확인 중…", action: nil, keyEquivalent: "")
    private let usedItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let timeItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let paceItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let resetItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let updatedItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let errorItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let refreshItem = NSMenuItem(title: "지금 새로고침", action: #selector(refresh), keyEquivalent: "r")
    private var window: NSWindow!
    private let bigLabel = NSTextField(labelWithString: "확인 중…")
    private let resetLabel = NSTextField(labelWithString: "초기화 시각 확인 중")
    private let updateLabel = NSTextField(labelWithString: "")
    private let messageLabel = NSTextField(wrappingLabelWithString: "")
    private let progress = NSProgressIndicator()
    private let timeLabel = NSTextField(labelWithString: "주간 시간 확인 중…")
    private let timeProgress = NSProgressIndicator()
    private let paceLabel = NSTextField(wrappingLabelWithString: "")
    private var refreshButton: NSButton!
    private var timer: Timer?
    private var usage: WeeklyUsage?
    private var lastError: String?
    private var fetching = false
    private var codexBinary: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createMenu()
        createWindow()
        do { codexBinary = try CodexLocation.binaryURL() }
        catch { lastError = error.localizedDescription }
        render()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.refresh() }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        if !UserDefaults.standard.bool(forKey: "DidShowWelcome") {
            UserDefaults.standard.set(true, forKey: "DidShowWelcome")
            showDetails()
        }
    }

    private func createMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = NSImage(systemSymbolName: "chart.pie", accessibilityDescription: "Codex 주간 잔량")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.imagePosition = .imageLeading
        menu.autoenablesItems = false
        menu.delegate = self
        for item in [titleItem, usedItem, timeItem, paceItem, resetItem, updatedItem, errorItem] {
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())
        refreshItem.target = self
        menu.addItem(refreshItem)
        addAction("사용량 보기…", #selector(showDetails))
        addAction("Codex 열기", #selector(openCodex))
        let note = NSMenuItem(title: "1분마다 자동 갱신 · 주간 한도 기준", action: nil, keyEquivalent: "")
        note.isEnabled = false
        menu.addItem(note)
        menu.addItem(.separator())
        addAction("종료", #selector(quit), key: "q")
        statusItem.menu = menu
    }

    private func addAction(_ title: String, _ action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    private func createWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 440), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Codex 주간 잔량"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        let caption = NSTextField(labelWithString: "Codex 주간 사용 한도 · 남은 시간 비교")
        caption.font = .systemFont(ofSize: 14, weight: .medium)
        caption.textColor = .secondaryLabelColor
        bigLabel.font = .monospacedDigitSystemFont(ofSize: 28, weight: .semibold)
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        paceLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        paceLabel.maximumNumberOfLines = 2
        let explanation = NSTextField(wrappingLabelWithString: "남은 시간은 다음 초기화까지의 시간을 7일로 나눈 비율입니다.")
        explanation.font = .systemFont(ofSize: 11)
        explanation.textColor = .secondaryLabelColor
        resetLabel.font = .systemFont(ofSize: 13)
        updateLabel.font = .systemFont(ofSize: 12)
        updateLabel.textColor = .secondaryLabelColor
        messageLabel.font = .systemFont(ofSize: 12)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.maximumNumberOfLines = 3
        for bar in [progress, timeProgress] {
            bar.isIndeterminate = false
            bar.minValue = 0
            bar.maxValue = 100
            bar.style = .bar
            bar.controlSize = .regular
        }
        refreshButton = NSButton(title: "새로고침", target: self, action: #selector(refresh))
        refreshButton.bezelStyle = .rounded
        let openButton = NSButton(title: "Codex 열기", target: self, action: #selector(openCodex))
        openButton.bezelStyle = .rounded
        let buttons = NSStackView(views: [refreshButton, openButton])
        buttons.spacing = 8
        let stack = NSStackView(views: [caption, bigLabel, progress, timeLabel, timeProgress, paceLabel, explanation, resetLabel, updateLabel, messageLabel, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 13
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 25),
            progress.widthAnchor.constraint(equalTo: stack.widthAnchor),
            timeProgress.widthAnchor.constraint(equalTo: stack.widthAnchor),
            paceLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            explanation.widthAnchor.constraint(equalTo: stack.widthAnchor),
            messageLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    func menuWillOpen(_ menu: NSMenu) { render() }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = .current
        formatter.dateFormat = "M월 d일 (E) HH:mm"
        return formatter.string(from: date)
    }

    private func render() {
        let now = Date()
        let expired = usage?.isExpired(at: now) ?? false
        let stale = lastError != nil || (usage.map { now.timeIntervalSince($0.fetchedAt) > 150 } ?? false)
        let comparison = UsageComparison(usage: usage, at: now, isStale: stale)
        if let usage, !expired {
            statusItem.button?.title = "\(usage.remainingText)\(stale ? " · ?" : "")"
            titleItem.title = "주간 잔여 \(usage.remainingText)\(stale ? " (마지막 확인값)" : "")"
            usedItem.title = "사용 \(usage.usedText) · 남음 \(usage.remainingText)"
            bigLabel.stringValue = "사용 한도 \(UsageComparison.percentText(usage.remainingPercent)) 남음"
            progress.doubleValue = usage.remainingPercent
        } else {
            statusItem.button?.title = fetching ? "…" : "—"
            titleItem.title = expired ? "초기화 후 사용량 확인 필요" : "주간 사용량 확인 필요"
            usedItem.title = "사용량을 확인하면 잔량이 표시됩니다"
            bigLabel.stringValue = fetching ? "확인 중…" : "확인 필요"
            progress.doubleValue = 0
        }
        progress.isHidden = usage == nil || expired
        timeItem.title = comparison.timeText
        paceItem.title = comparison.paceText
        timeLabel.stringValue = comparison.timeText
        timeProgress.doubleValue = comparison.timeRemainingPercent ?? 0
        timeProgress.isHidden = comparison.timeRemainingPercent == nil
        paceLabel.stringValue = comparison.paceText
        switch comparison.pace {
        case .ahead: paceLabel.textColor = .systemGreen
        case .behind: paceLabel.textColor = .systemOrange
        case .balanced: paceLabel.textColor = .labelColor
        case .stale, .unavailable: paceLabel.textColor = .secondaryLabelColor
        }
        resetItem.title = usage?.resetsAt.map { "초기화: \(dateText($0))" } ?? "초기화 시각: 정보 없음"
        updatedItem.title = usage.map { "마지막 확인: \(dateText($0.fetchedAt))" } ?? "아직 조회하지 못했습니다"
        errorItem.title = lastError ?? (expired ? "새로고침으로 새 한도를 확인하세요" : "")
        errorItem.isHidden = lastError == nil && !expired
        resetLabel.stringValue = resetItem.title
        updateLabel.stringValue = updatedItem.title
        messageLabel.stringValue = lastError.map { "\($0)\n잠시 후 자동으로 다시 확인합니다." }
            ?? (expired ? (fetching ? "초기화된 한도를 다시 확인하고 있습니다." : "주간 초기화 시각이 지났습니다. 새로고침해 주세요.")
                : (stale ? "마지막으로 확인한 값입니다. 새로고침해 주세요." : "상단 메뉴 막대에서도 볼 수 있습니다.\n1분마다 자동 갱신합니다."))
        statusItem.button?.toolTip = [titleItem.title, timeItem.title, paceItem.title, resetItem.title, updatedItem.title, lastError].compactMap { $0 }.joined(separator: "\n")
        refreshItem.isEnabled = !fetching
        refreshButton?.isEnabled = !fetching
    }

    @objc private func refresh() {
        guard !fetching else { return }
        if codexBinary == nil { codexBinary = try? CodexLocation.binaryURL() }
        guard let binary = codexBinary else {
            lastError = "Codex 앱을 찾지 못했습니다. Codex를 설치하고 로그인해 주세요."
            render()
            return
        }
        fetching = true
        render()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = Result { try UsageModel.parse(UsageRPC.fetch(executableURL: binary)) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.fetching = false
                switch result {
                case .success(let usage): self.usage = usage; self.lastError = nil
                case .failure(let error): self.lastError = error.localizedDescription
                }
                self.render()
            }
        }
    }

    @objc private func didWake() { refresh() }

    @objc private func showDetails() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        render()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showDetails()
        return false
    }

    @objc private func openCodex() {
        guard let url = CodexLocation.appURL else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

if CommandLine.arguments.contains("--status") {
    do {
        let result = try UsageRPC.fetch(executableURL: CodexLocation.binaryURL())
        let usage = try UsageModel.parse(result)
        let now = Date()
        let pace = usage.pace(at: now)
        let summary: [String: Any] = [
            "weeklyRemainingPercent": usage.remainingPercent,
            "weeklyUsedPercent": usage.usedPercent,
            "weeklyTimeRemainingPercent": usage.timeRemainingPercent(at: now) as Any? ?? NSNull(),
            "weeklyAllowanceAheadPercentagePoints": pace?.differencePercentagePoints as Any? ?? NSNull(),
            "weeklySecondsRemaining": pace?.secondsRemaining as Any? ?? NSNull(),
            "resetsAt": usage.resetsAt.map { Int($0.timeIntervalSince1970) } as Any? ?? NSNull(),
            "fetchedAt": Int(usage.fetchedAt.timeIntervalSince1970)
        ]
        print(String(decoding: try JSONSerialization.data(withJSONObject: summary, options: [.sortedKeys]), as: UTF8.self))
        exit(0)
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

let application = NSApplication.shared
let delegate = WeeklyApp()
application.delegate = delegate
application.run()
