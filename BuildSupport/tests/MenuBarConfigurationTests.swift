import Foundation
import Defaults

@main struct MenuBarConfigurationTests {
    static func main() {
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message); checks += 1
        }
        check(AidenteRuntime.isUIPreview, "Run preference tests only with --ui-preview")
        check(Defaults.Keys.chargeLimit.suite === AidenteRuntime.preferenceStore, "Charging preferences use isolated preview store")
        check(Defaults.Keys.menuBarMetrics.suite === AidenteRuntime.preferenceStore, "Menu preferences use same preview store")
        check(Defaults.Keys.popoverWidgets.suite === AidenteRuntime.preferenceStore, "Widget preferences use same preview store")
        check(AidenteRuntime.preferenceStore !== UserDefaults.standard, "Preview must not use production defaults")
        let valid = MenuBarMetric.selected(from: ["temperature", "unknown", "temperature", "adapterPower"])
        check(valid == [.temperature, .adapterPower], "Corrupt and duplicate metrics are removed without losing ordering")
        check(MenuBarMetric.selected(from: []).isEmpty, "An empty selection stays empty")
        check(MenuBarMetric.selected(from: MenuBarMetric.allCases.map(\.id)) == MenuBarMetric.allCases, "Every readout round-trips")
        let widgets = PopoverWidget.selected(from: ["careActions", "unknown", "careActions", "powerFlow"])
        check(widgets == [.careActions, .powerFlow], "Widgets preserve saved order and ignore invalid IDs")
        check(PopoverWidget.selected(from: []).isEmpty, "Empty widget layout remains empty")
        check(Set(MenuBarIconStyle.allCases.map(\.id)).count == MenuBarIconStyle.allCases.count, "Unique stable style IDs")
        check(MenuBarIconStyle.allCases.contains(.hidden), "Hidden icon supported without requiring hidden readouts")
        let original = Defaults[.menuBarMetrics]
        Defaults[.menuBarMetrics] = ["temperature", "adapterPower"]
        check(Defaults[.menuBarMetrics] == ["temperature", "adapterPower"], "Ordered settings persist")
        Defaults[.menuBarMetrics] = original
        print("Passed \(checks) menu configuration checks (isolated preview preferences)")
    }
}
