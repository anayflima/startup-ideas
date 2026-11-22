import AppIntents
import Foundation

// LiveActivityIntent = runs in the app's process, so the Live Activity can be updated or ended right away.

struct StopTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Pavoot timer"
    static var description = IntentDescription("Stops your running Pavoot Hours timer.")
    init() {}
    func perform() async throws -> some IntentResult {
        try await Actions.stop()
        return .result()
    }
}

struct StartTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start Pavoot timer"
    static var description = IntentDescription("Starts a Pavoot Hours timer on a topic (stops the running one).")
    @Parameter(title: "Topic", default: "") var topic: String
    @Parameter(title: "Not work", default: false) var notWork: Bool
    init() {}
    init(topic: String, notWork: Bool) {
        self.topic = topic
        self.notWork = notWork
    }
    func perform() async throws -> some IntentResult {
        try await Actions.start(topic, notWork)
        return .result()
    }
}

struct ToggleTimerIntent: SetValueIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "Start or stop Pavoot timer"
    @Parameter(title: "Running") var value: Bool
    init() {}
    func perform() async throws -> some IntentResult {
        if value {
            let l = Store.snap?.last
            try await Actions.start(l?.n ?? "", l?.p ?? false)
        } else {
            try await Actions.stop()
        }
        return .result()
    }
}
