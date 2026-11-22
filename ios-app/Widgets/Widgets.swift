import WidgetKit
import SwiftUI
import AppIntents
import ActivityKit

let bgC = Color(red: 6/255, green: 20/255, blue: 24/255)
let tealC = Color(red: 0x24/255, green: 0xbd/255, blue: 0xbb/255)
let nwC = Color(red: 0xf4/255, green: 0xb6/255, blue: 0x78/255)
let stopC = Color(red: 0xe5/255, green: 0x48/255, blue: 0x4d/255)

@main
struct HoursWidgets: WidgetBundle {
    var body: some Widget {
        StatusWidget()
        HoursLiveActivity()
        HoursControl()
    }
}

func pill(_ t: String, _ img: String, _ c: Color) -> some View {
    HStack(spacing: 4) {
        Image(systemName: img).font(.system(size: 10, weight: .bold))
        Text(t).font(.system(size: 12, weight: .semibold)).lineLimit(1)
    }
    .padding(.horizontal, 8).padding(.vertical, 7)
    .frame(maxWidth: .infinity)
    .background(Capsule().fill(c.opacity(0.22)))
    .foregroundStyle(c)
}

func topicText(_ n: String) -> String { n.isEmpty ? "No description" : n }

// MARK: Home + Lock Screen widget

struct HEntry: TimelineEntry {
    let date: Date
    let snap: Snap
    let signedIn: Bool
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> HEntry { HEntry(date: Date(), snap: .sample, signedIn: true) }
    func getSnapshot(in context: Context, completion: @escaping (HEntry) -> Void) {
        completion(HEntry(date: Date(), snap: Store.snap ?? .sample, signedIn: true))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HEntry>) -> Void) {
        Task {
            let signed = Store.key != nil
            let s = (await Actions.fetch()) ?? Store.snap ?? .empty
            let e = HEntry(date: Date(), snap: s, signedIn: signed)
            completion(Timeline(entries: [e], policy: .after(Date().addingTimeInterval(15 * 60))))
        }
    }
}

struct StatusView: View {
    @Environment(\.widgetFamily) var family
    let e: HEntry
    var run: Run? { e.snap.running }
    var startLast: StartTimerIntent { StartTimerIntent(topic: e.snap.last?.n ?? "", notWork: e.snap.last?.p ?? false) }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rect
        case .accessoryInline: inline
        case .systemMedium: medium
        default: small
        }
    }

    @ViewBuilder var inline: some View {
        if let r = run {
            Text("\(topicText(r.n)) ") + Text(r.s, style: .timer)
        } else {
            Text("Pavoot: not tracking")
        }
    }

    @ViewBuilder var circular: some View {
        if let r = run {
            Button(intent: StopTimerIntent()) {
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 1) {
                        Image(systemName: "stop.fill").font(.system(size: 11))
                        Text(r.s, style: .timer).font(.system(size: 11, weight: .semibold)).monospacedDigit()
                            .multilineTextAlignment(.center).minimumScaleFactor(0.5).lineLimit(1)
                    }.padding(.horizontal, 3)
                }
            }.buttonStyle(.plain)
        } else {
            Button(intent: startLast) {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "play.fill").font(.title3)
                }
            }.buttonStyle(.plain)
        }
    }

    @ViewBuilder var rect: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                if let r = run {
                    Label(r.p ? "Not work" : "Working", systemImage: kindIcon(r.p)).font(.caption2).widgetAccentable()
                    Text(topicText(r.n)).font(.headline).lineLimit(1)
                    Text(r.s, style: .timer).font(.system(.body, design: .rounded).weight(.semibold)).monospacedDigit()
                } else {
                    Label("Pavoot Hours", systemImage: "timer").font(.caption2).widgetAccentable()
                    Text(e.signedIn ? "Not tracking" : "Sign in in the app").font(.headline).lineLimit(1)
                    Text("Today " + hm(e.snap.todayWork)).font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if run != nil {
                Button(intent: StopTimerIntent()) { Image(systemName: "stop.circle.fill").font(.title) }.buttonStyle(.plain)
            } else if e.signedIn {
                Button(intent: startLast) { Image(systemName: "play.circle.fill").font(.title) }.buttonStyle(.plain)
            }
        }
    }

    var header: some View {
        HStack(spacing: 4) {
            Image(systemName: run.map { kindIcon($0.p) } ?? "timer").font(.system(size: 11, weight: .bold))
            Text(run.map { $0.p ? "NOT WORK" : "WORKING" } ?? "PAVOOT HOURS").font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(run.map { $0.p ? nwC : tealC } ?? Color.white.opacity(0.6))
    }

    @ViewBuilder var status: some View {
        if let r = run {
            Text(topicText(r.n)).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
            Text(r.s, style: .timer).font(.system(size: 26, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
        } else {
            Text(e.signedIn ? "Not tracking" : "Open the app to sign in").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
            Text("Today " + hm(e.snap.todayWork)).font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
        }
    }

    @ViewBuilder var mainButton: some View {
        if run != nil {
            Button(intent: StopTimerIntent()) { pill("Stop", "stop.fill", stopC) }.buttonStyle(.plain)
        } else if e.signedIn {
            Button(intent: startLast) { pill(e.snap.last.map { $0.n.isEmpty ? "Start" : $0.n } ?? "Start", "play.fill", tealC) }.buttonStyle(.plain)
        }
    }

    var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            status
            Spacer(minLength: 0)
            mainButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var medium: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                header
                status
                Spacer(minLength: 0)
                mainButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if e.signedIn {
                VStack(alignment: .leading, spacing: 5) {
                    Text(run == nil ? "START" : "SWITCH TO").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                    ForEach(Array(e.snap.sugg.prefix(3)), id: \.self) { c in
                        Button(intent: StartTimerIntent(topic: c.n, notWork: c.p)) {
                            pill(c.n, c.p ? "cup.and.saucer.fill" : "play.fill", c.p ? nwC : tealC)
                        }.buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

struct StatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PavootHoursStatus", provider: Provider()) { e in
            StatusView(e: e).containerBackground(for: .widget) { bgC }
        }
        .configurationDisplayName("Pavoot timer")
        .description("See what is running, stop it or switch topic.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

// MARK: Live Activity (Dynamic Island + Lock Screen while a timer runs)

struct ActionRow: View {
    let st: HoursActivity.ContentState
    let limit: Int
    var body: some View {
        HStack(spacing: 6) {
            Button(intent: StopTimerIntent()) { pill("Stop", "stop.fill", stopC) }.buttonStyle(.plain)
            ForEach(Array(st.sugg.prefix(limit)), id: \.self) { c in
                Button(intent: StartTimerIntent(topic: c.n, notWork: c.p)) {
                    pill(c.n, c.p ? "cup.and.saucer.fill" : "play.fill", c.p ? nwC : tealC)
                }.buttonStyle(.plain)
            }
        }
    }
}

struct LockView: View {
    let st: HoursActivity.ContentState
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(st.p ? "Not work" : "Working", systemImage: kindIcon(st.p))
                    .font(.caption.weight(.semibold)).foregroundStyle(st.p ? nwC : tealC)
                Spacer()
                Text("Pavoot Hours").font(.caption2).foregroundStyle(.white.opacity(0.6))
            }
            HStack(alignment: .firstTextBaseline) {
                Text(topicText(st.n)).font(.headline).foregroundStyle(.white).lineLimit(1)
                Spacer()
                Text(st.s, style: .timer).font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(.white).multilineTextAlignment(.trailing).frame(maxWidth: 130, alignment: .trailing)
            }
            ActionRow(st: st, limit: 3)
        }
        .padding(14)
    }
}

struct HoursLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HoursActivity.self) { ctx in
            LockView(st: ctx.state)
                .activityBackgroundTint(bgC)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { ctx in
            let st = ctx.state
            let c = st.p ? nwC : tealC
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(st.p ? "Not work" : "Working", systemImage: kindIcon(st.p)).font(.caption).foregroundStyle(c)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(st.s, style: .timer).font(.title3.weight(.semibold)).monospacedDigit()
                        .multilineTextAlignment(.trailing).frame(maxWidth: 96, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(topicText(st.n)).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ActionRow(st: st, limit: 2)
                }
            } compactLeading: {
                Image(systemName: kindIcon(st.p)).foregroundStyle(c)
            } compactTrailing: {
                Text(st.s, style: .timer).monospacedDigit().multilineTextAlignment(.trailing)
                    .frame(maxWidth: 56).foregroundStyle(c)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(c)
            }
            .keylineTint(c)
        }
    }
}

// MARK: Control (Lock Screen button / Control Center, iOS 18)

struct ControlProv: ControlValueProvider {
    var previewValue: Bool { false }
    func currentValue() async throws -> Bool {
        let s = (await Actions.fetch()) ?? Store.snap
        return s?.running != nil
    }
}

struct HoursControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "ch.pavoot.hours.control", provider: ControlProv()) { isOn in
            ControlWidgetToggle("Pavoot timer", isOn: isOn, action: ToggleTimerIntent()) { on in
                Label(on ? "Running" : "Stopped", systemImage: on ? "stop.fill" : "play.fill")
            }
            .tint(tealC)
        }
        .displayName("Pavoot timer")
        .description("Start or stop your Pavoot Hours timer.")
    }
}
