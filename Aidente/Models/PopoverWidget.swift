import Defaults
import Foundation

enum PopoverWidget: String, CaseIterable, Identifiable {
    case powerFlow, batterySpecs, capacityHistory, energyApps, careActions, protection, settingsLinks
    var id: String { rawValue }
    var title: String {
        switch self {
        case .powerFlow: return AidenteL10n.t("功率分配图", "Power Flow")
        case .batterySpecs: return AidenteL10n.t("电池规格", "Battery Specifications")
        case .capacityHistory: return AidenteL10n.t("容量趋势", "Capacity History")
        case .energyApps: return AidenteL10n.t("使用大量能耗的 App", "Apps Using Significant Energy")
        case .careActions: return AidenteL10n.t("快捷养护", "Battery Care")
        case .protection: return AidenteL10n.t("自动保护", "Automatic Protection")
        case .settingsLinks: return AidenteL10n.t("设置入口", "Settings Links")
        }
    }
    static func selected(from ids: [String]) -> [Self] {
        var seen = Set<String>()
        return ids.compactMap { seen.insert($0).inserted ? Self(rawValue: $0) : nil }
    }
}

extension Defaults.Keys {
    static let popoverWidgets = Key<[String]>("popoverWidgets",
        default: PopoverWidget.allCases.map(\.id), suite: AidenteRuntime.preferenceStore)
}
