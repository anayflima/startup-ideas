import Foundation
import Security
import WidgetKit
import ActivityKit

// Shared by the app and the widget extension: sign-in key + last known timer state (shared keychain group),
// the Neon Data API calls, and the start/stop actions used by widgets, the Live Activity and the Control.

struct Sugg: Codable, Hashable { var n: String; var p: Bool }
struct Run: Codable, Hashable { var n: String; var s: Date; var p: Bool }

struct Snap: Codable, Equatable {
    var running: Run?
    var sugg: [Sugg]
    var last: Sugg?
    var todayWork: Double
    var name: String
    var updated: Date
    static let empty = Snap(running: nil, sugg: [], last: nil, todayWork: 0, name: "", updated: .distantPast)
    static var sample: Snap {
        Snap(running: Run(n: "Product work", s: Date().addingTimeInterval(-3725), p: false),
             sugg: [Sugg(n: "Meetings", p: false), Sugg(n: "Meal", p: true), Sugg(n: "Calls", p: true)],
             last: Sugg(n: "Product work", p: false), todayWork: 14400, name: "", updated: Date())
    }
}

struct HoursActivity: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var n: String
        var s: Date
        var p: Bool
        var sugg: [Sugg]
    }
    var who: String
}

func hm(_ sec: Double) -> String {
    let m = Int(max(0, sec) / 60)
    return "\(m / 60)h " + String(format: "%02d", m % 60) + "m"
}
func kindIcon(_ p: Bool) -> String { p ? "cup.and.saucer.fill" : "briefcase.fill" }

enum Store {
    private static let service = "ch.pavoot.hours.shared"
    private static func base(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
    static func readData(_ account: String) -> Data? {
        var q = base(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }
    static func writeData(_ account: String, _ data: Data?) {
        let q = base(account)
        guard let data = data else { SecItemDelete(q as CFDictionary); return }
        let attrs: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(q as CFDictionary, attrs as CFDictionary) != errSecSuccess {
            var add = q
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemDelete(q as CFDictionary)
            SecItemAdd(add as CFDictionary, nil)
        }
    }
    static var key: String? {
        get { readData("key").flatMap { String(data: $0, encoding: .utf8) } }
        set { writeData("key", newValue?.data(using: .utf8)) }
    }
    static var snap: Snap? {
        get { readData("snap").flatMap { try? JSONDecoder().decode(Snap.self, from: $0) } }
        set { writeData("snap", newValue.flatMap { try? JSONEncoder().encode($0) }) }
    }
}

struct APIError: LocalizedError {
    var msg: String
    var errorDescription: String? { msg }
}

enum API {
    static let rest = "https://ep-sweet-heart-b9jc9c7i.apirest.c-7.eu-central-1.aws.neon.tech/neondb/rest/v1"
    static let auth = "https://ep-sweet-heart-b9jc9c7i.neonauth.c-7.eu-central-1.aws.neon.tech/neondb/auth/token/anonymous"

    static func token() async throws -> String {
        var r = URLRequest(url: URL(string: auth)!)
        r.cachePolicy = .reloadIgnoringLocalCacheData
        r.timeoutInterval = 15
        let (d, _) = try await URLSession.shared.data(for: r)
        guard let j = try JSONSerialization.jsonObject(with: d) as? [String: Any], let t = j["token"] as? String else {
            throw APIError(msg: "Could not reach the server")
        }
        return t
    }

    static func rpc(_ fn: String, _ args: [String: Any] = [:]) async throws -> [String: Any] {
        guard let key = Store.key else { throw APIError(msg: "Open Pavoot Hours and sign in first") }
        var body = args
        body["p_key"] = key
        for attempt in 0..<2 {
            let t = try await token()
            var r = URLRequest(url: URL(string: rest + "/rpc/" + fn)!)
            r.httpMethod = "POST"
            r.timeoutInterval = 20
            r.setValue("Bearer " + t, forHTTPHeaderField: "Authorization")
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (d, resp) = try await URLSession.shared.data(for: r)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let j = try? JSONSerialization.jsonObject(with: d)
            if (200..<300).contains(code), let o = j as? [String: Any] { return o }
            if attempt == 0 && code == 401 { continue }
            throw APIError(msg: ((j as? [String: Any])?["message"] as? String) ?? "HTTP \(code)")
        }
        throw APIError(msg: "Could not reach the server")
    }
}

enum Model {
    static let workDefaults = ["Meetings"]
    static let nwDefaults = ["Meal", "Calls", "Commuting", "Apartment search", "Personal"]

    static func str(_ v: Any?) -> String {
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        return ""
    }

    static func date(_ v: Any?) -> Date? {
        guard var s = v as? String, !s.isEmpty else { return nil }
        s = s.replacingOccurrences(of: " ", with: "T")
        var frac = 0.0
        if let t = s.firstIndex(of: "T"), let dot = s[t...].firstIndex(of: ".") {
            var end = s.index(after: dot)
            while end < s.endIndex, s[end].isNumber { end = s.index(after: end) }
            frac = Double("0" + String(s[dot..<end])) ?? 0
            s = String(s[..<dot]) + String(s[end...])
        }
        if s.range(of: "[+-][0-9]{2}$", options: .regularExpression) != nil { s += ":00" }
        let f = ISO8601DateFormatter()
        return f.date(from: s).map { $0.addingTimeInterval(frac) }
    }

    struct E { var n: String; var s: Date; var e: Date?; var p: Bool }

    static func snap(from d: [String: Any]) -> Snap {
        let me = str(d["me"])
        let users = d["users"] as? [[String: Any]] ?? []
        let name = str(users.first(where: { str($0["id"]) == me })?["name"])
        var mine: [E] = []
        for x in d["entries"] as? [[String: Any]] ?? [] {
            guard str(x["u"]) == me, let s = date(x["s"]) else { continue }
            var n = str(x["n"]).trimmingCharacters(in: .whitespacesAndNewlines)
            if n.lowercased() == "lunch" { n = "Meal" }
            mine.append(E(n: n, s: s, e: date(x["e"]), p: (x["p"] as? Bool) ?? false))
        }
        mine.sort { $0.s < $1.s }
        let r = mine.last(where: { $0.e == nil })
        var seen = Set<String>()
        if let r = r { seen.insert((r.p ? "p:" : "w:") + r.n.lowercased()) }
        var work: [Sugg] = []
        var nw: [Sugg] = []
        for x in mine.reversed() where x.e != nil && !x.n.isEmpty {
            let k = (x.p ? "p:" : "w:") + x.n.lowercased()
            if seen.contains(k) { continue }
            seen.insert(k)
            if x.p { nw.append(Sugg(n: x.n, p: true)) } else { work.append(Sugg(n: x.n, p: false)) }
        }
        for n in workDefaults where !seen.contains("w:" + n.lowercased()) { work.append(Sugg(n: n, p: false)) }
        for n in nwDefaults where !seen.contains("p:" + n.lowercased()) { nw.append(Sugg(n: n, p: true)) }
        // On a break: back-to-work topics first. Working: mix work topics with break options.
        let pattern: [Bool] = (r?.p ?? false) ? [false, false, true, false, true, false] : [false, true, false, true, false, true]
        var sugg: [Sugg] = []
        var wi = 0, ni = 0
        for wantNW in pattern where sugg.count < 4 {
            if wantNW {
                if ni < nw.count { sugg.append(nw[ni]); ni += 1 }
            } else if wi < work.count {
                sugg.append(work[wi]); wi += 1
            }
        }
        let lastE = mine.last(where: { $0.e != nil })
        let now = Date()
        let sod = Calendar.current.startOfDay(for: now)
        var today = 0.0
        for x in mine where !x.p {
            guard let e = x.e else { continue }
            let a = max(x.s, sod), b = min(e, now)
            if b > a { today += b.timeIntervalSince(a) }
        }
        return Snap(running: r.map { Run(n: $0.n, s: $0.s, p: $0.p) }, sugg: sugg,
                    last: lastE.map { Sugg(n: $0.n, p: $0.p) }, todayWork: today, name: name, updated: now)
    }
}

extension Notification.Name {
    static let hoursChanged = Notification.Name("PavootHoursChanged")
}

enum Actions {
    /// Set by the app at launch: keeps the Live Activity (Dynamic Island / Lock Screen) in step.
    static var onApply: ((Snap?) async -> Void)?

    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
    }

    @discardableResult
    static func apply(_ d: [String: Any]) async -> Snap {
        let s = Model.snap(from: d)
        var a = s, b = Store.snap ?? .empty
        a.updated = .distantPast
        b.updated = .distantPast
        Store.snap = s
        if a != b { reloadWidgets() }
        if let f = onApply { await f(s) }
        return s
    }

    /// Fresh state for widget timelines (no reload, so no reload loop).
    static func fetch() async -> Snap? {
        guard Store.key != nil else { return nil }
        guard let d = try? await API.rpc("hr_state") else { return nil }
        let s = Model.snap(from: d)
        Store.snap = s
        return s
    }

    static func start(_ n: String, _ p: Bool) async throws {
        let d = try await API.rpc("hr_start", ["p_note": n, "p_nw": p])
        await apply(d)
        NotificationCenter.default.post(name: .hoursChanged, object: nil)
    }

    static func stop() async throws {
        let d = try await API.rpc("hr_stop")
        await apply(d)
        NotificationCenter.default.post(name: .hoursChanged, object: nil)
    }

    static func signOut() async {
        Store.key = nil
        Store.snap = nil
        reloadWidgets()
        if let f = onApply { await f(nil) }
    }
}
