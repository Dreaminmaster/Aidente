import Foundation
import AidenteShared

@main struct HeatProtectionTests {
    static func main() {
        var policy = HeatProtectionPolicy()
        let start = Date(timeIntervalSince1970: 1000)
        var checks = 0
        func check(_ actual: Bool, _ expected: Bool, _ title: String) {
            precondition(actual == expected, title); checks += 1
        }
        func pause(_ seconds: Double, _ temperature: Double, _ enabled: Bool = true, _ charging: Bool = true) -> Bool {
            policy.shouldPause(temperature: temperature, limit: 35, enabled: enabled,
                chargingRequested: charging, now: start.addingTimeInterval(seconds))
        }
        check(pause(0, 30), false, "Cold initial charge")
        check(pause(1, 35), true, "Pause at threshold")
        check(pause(100, 30), true, "Cooling cannot end five-minute pause early")
        check(pause(301, 36), true, "Hot reading starts another pause window")
        check(pause(600, 30), true, "Repeated pause also lasts five minutes")
        check(pause(601, 34.9), false, "Cool below threshold resumes charge without arbitrary one-degree delta")
        check(pause(602, 40), false, "Resumed charging has minimum five-minute window")
        check(pause(900, 40), false, "Minimum charging window persists")
        check(pause(901, 40), true, "Hot state pauses when charging window expires")
        check(pause(902, 40, false), false, "Disabled protection resets")
        check(pause(903, 40), true, "Reenabled hot battery pauses immediately")
        check(pause(904, 40, true, false), false, "Manual hold must retain its own operation status")
        check(pause(905, 30), false, "Reactivation after hold has fresh state")
        check(pause(906, .nan), true, "Invalid sensor reading cannot approve charging")
        print("Passed \(checks) thermal-window checks (hardware-free)")
    }
}
