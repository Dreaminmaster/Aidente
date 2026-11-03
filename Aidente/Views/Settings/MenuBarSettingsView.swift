import Defaults
import SwiftUI

struct MenuBarSettingsView: View {
    @Default(.menuBarIconStyle) private var iconStyle
    @Default(.menuBarMetrics) private var metricIDs
    @Default(.menuBarItemSpacing) private var itemSpacing
    @Default(.menuBarUpdateInterval) private var updateInterval
    @Default(.menuBarRightClick) private var rightClick
    @Default(.menuBarLowPowerColor) private var lowPowerColor
    @Default(.batteryPercentageDisplayLocation) private var percentageLocation
    @Default(.showBatteryStateInStatusIcon) private var stateColors
    @Default(.menuBarReadoutStyle) private var legacyReadout
    @State private var draggedMetric: String?

    private var selected: [MenuBarMetric] { MenuBarMetric.selected(from: metricIDs) }
    private var groups: [String] {
        MenuBarMetric.allCases.reduce(into: []) { result, metric in
            if !result.contains(metric.group) { result.append(metric.group) }
        }
    }

    var body: some View {
        AidenteSettingsPage {
            AidenteCard("已选菜单栏项目", subtitle: "拖动调整读数顺序，点击减号移除。", icon: "menubar.rectangle", colors: AidenteTheme.generalColors) {
                ScrollView(.horizontal) {
                HStack(spacing: CGFloat(itemSpacing)) {
                    BatteryIndicatorView(batteryLevel: 76, chargingMode: .pluggedIn,
                        percentageDisplayLocation: percentageLocation, showState: stateColors,
                        style: iconStyle, adapterConnected: true)
                    ForEach(selected) { metric in
                        HStack(spacing: 5) {
                            Label(metric.title, systemImage: metric.icon)
                            Button { metricIDs.removeAll { $0 == metric.id } } label: {
                                Image(systemName: "minus.circle.fill")
                            }.buttonStyle(.borderless)
                        }
                        .padding(8).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                        .onDrag { draggedMetric = metric.id; return NSItemProvider(object: metric.id as NSString) }
                        .onDrop(of: [.text], delegate: MetricReorderDropDelegate(
                            target: metric.id, values: $metricIDs, dragged: $draggedMetric))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .fixedSize(horizontal: true, vertical: false)
                }.frame(height: 58)
                Text(AidenteL10n.t("上方图标使用示例电量，菜单栏显示实际读数。", "Icon preview uses sample data; the menu bar shows live readings."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            AidenteCard("主图标样式", subtitle: "选择一个主图标。", icon: "battery.75percent", colors: AidenteTheme.chargingColors) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], spacing: 12) {
                    ForEach(MenuBarIconStyle.allCases) { style in
                        Button { iconStyle = style } label: {
                            VStack(spacing: 10) {
                                if style == .hidden { Image(systemName: "eye.slash").frame(height: 22) }
                                else {
                                    BatteryIndicatorView(batteryLevel: 76, chargingMode: .charging,
                                        percentageDisplayLocation: .insideIcon, showState: true, style: style)
                                        .frame(height: 22)
                                }
                                Text(style.title).font(.caption)
                            }
                            .frame(maxWidth: .infinity).padding(12)
                            .background(iconStyle == style ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(iconStyle == style ? Color.accentColor : .clear))
                        }.buttonStyle(.plain)
                    }
                }
                Picker(AidenteL10n.t("电量数字位置", "Percentage Position"), selection: $percentageLocation) {
                    Text(AidenteL10n.t("不显示", "Hidden")).tag(PercentageDisplayLocation.hidden)
                    Text(AidenteL10n.t("图标旁", "Beside Icon")).tag(PercentageDisplayLocation.nextToIcon)
                    Text(AidenteL10n.t("图标内", "Inside Icon")).tag(PercentageDisplayLocation.insideIcon)
                }.disabled(iconStyle == .hidden)
                Toggle(AidenteL10n.t("低电量模式颜色", "Low Power Mode Color"), isOn: $lowPowerColor)
                Toggle(AidenteL10n.t("用颜色显示电池状态", "Color by Battery State"), isOn: $stateColors)
            }
            ForEach(groups, id: \.self) { group in
                AidenteCard(group, subtitle: "点击添加到菜单栏。", icon: "plus.circle", colors: AidenteTheme.dashboardColors) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170))], alignment: .leading, spacing: 10) {
                        ForEach(MenuBarMetric.allCases.filter { $0.group == group }) { metric in
                            Toggle(isOn: Binding(get: { metricIDs.contains(metric.id) }, set: { enabled in
                                if enabled { if !metricIDs.contains(metric.id) { metricIDs.append(metric.id) } }
                                else { metricIDs.removeAll { $0 == metric.id } }
                            })) {
                                Label(metric.title, systemImage: metric.icon).font(.caption)
                            }.toggleStyle(.checkbox)
                        }
                    }
                }
            }
            AidenteCard("菜单栏选项", subtitle: "调整显示密度、刷新频率与鼠标操作。", icon: "slider.horizontal.3", colors: AidenteTheme.advancedColors) {
                Stepper(AidenteL10n.t("菜单栏项目间距：\(itemSpacing) 点", "Item Spacing: \(itemSpacing) pt"), value: $itemSpacing, in: 0...20)
                Stepper(AidenteL10n.t("菜单栏更新间隔：\(updateInterval) 秒", "Update Interval: \(updateInterval) s"), value: $updateInterval, in: 2...20)
                Picker(AidenteL10n.t("菜单栏右击", "Right Click"), selection: $rightClick) {
                    ForEach(MenuBarRightClick.allCases) { Text($0.title).tag($0) }
                }
                HStack {
                    Button(AidenteL10n.t("重置", "Reset")) {
                        iconStyle = .status; metricIDs = []; percentageLocation = .nextToIcon
                        lowPowerColor = true; stateColors = true; itemSpacing = 5; updateInterval = 5
                        legacyReadout = .batteryPercentage; rightClick = .popover
                    }
                    Button(AidenteL10n.t("全部清除", "Clear All")) {
                        iconStyle = .hidden; metricIDs = []; legacyReadout = .batteryPercentage
                    }
                }
                Text(AidenteL10n.t("隐藏全部项目后，可从“应用程序”重新打开 Aidente 仪表盘。", "If all items are hidden, reopen Aidente from Applications to show the dashboard."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct MetricReorderDropDelegate: DropDelegate {
    let target: String
    @Binding var values: [String]
    @Binding var dragged: String?
    func dropEntered(info: DropInfo) {
        guard let dragged, dragged != target,
              let source = values.firstIndex(of: dragged), let destination = values.firstIndex(of: target) else { return }
        withAnimation { values.move(fromOffsets: IndexSet(integer: source), toOffset: destination > source ? destination + 1 : destination) }
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { dragged = nil; return true }
}
