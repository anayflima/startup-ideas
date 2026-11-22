import ActivityKit
import Foundation

// App-only: starts, updates and ends the Live Activity that shows the running timer
// in the Dynamic Island and on the Lock Screen.
enum LiveSync {
    static func sync(_ s: Snap?) async {
        let acts = Activity<HoursActivity>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
        guard let s = s, let r = s.running else {
            for a in acts { await a.end(nil, dismissalPolicy: .immediate) }
            return
        }
        let st = HoursActivity.ContentState(n: r.n, s: r.s, p: r.p, sugg: Array(s.sugg.prefix(3)))
        if let a = acts.first {
            if a.content.state != st { await a.update(ActivityContent(state: st, staleDate: nil)) }
            for x in acts.dropFirst() { await x.end(nil, dismissalPolicy: .immediate) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            _ = try? Activity.request(attributes: HoursActivity(who: s.name),
                                      content: ActivityContent(state: st, staleDate: nil),
                                      pushType: nil)
        }
    }
}
