import SwiftUI

/// Shared geometry keeps the menu-bar allocation aligned with the rendered icon.
enum BatteryIndicatorLayout {
    static let bodyWidth: CGFloat = 16
    static let bodyHeight: CGFloat = 10
    static let insideBodyWidth: CGFloat = 22
    static let insideBodyHeight: CGFloat = 12
    static let terminalWidth: CGFloat = 1.5
    static let terminalHeight: CGFloat = 4
    static let terminalSpacing: CGFloat = 0.5
    static let outsideTextSpacing: CGFloat = 2
    static let statusInset: CGFloat = 1

    static func width(insidePercentage: Bool) -> CGFloat {
        (insidePercentage ? insideBodyWidth : bodyWidth) + terminalSpacing + terminalWidth
    }
}

struct BatteryIndicatorView: View {
    let batteryLevel: Int
    let chargingMode: ChargingMode
    var isLowPowerModeEnabled: Bool = false
    var percentageDisplayLocation: PercentageDisplayLocation = .hidden
    var showState: Bool = false
    var style: MenuBarIconStyle = .compact
    var adapterConnected: Bool = false

    private var shouldShowInsidePercentage: Bool {
        percentageDisplayLocation == .insideIcon
    }

    private var shouldShowOutsidePercentage: Bool {
        percentageDisplayLocation == .nextToIcon
    }

    private var isCritical: Bool {
        showState && batteryLevel <= 20
    }

    private var fillColor: Color {
        if isLowPowerModeEnabled { return AidenteTheme.gold }
        if !showState && style != .macOS26 { return Color(red: 0.62, green: 0.70, blue: 0.78) }
        if style == .macOS26 { return .primary }
        if style == .iOSNative && !isLowPowerModeEnabled {
            if batteryLevel <= 20 { return Color(red: 1, green: 0.28, blue: 0.30) }
            return chargingMode == .charging ? .green : Color(white: 0.92)
        }
        if isCritical { return Color(red: 0.99, green: 0.62, blue: 0.66) }
        if isLowPowerModeEnabled { return AidenteTheme.gold }
        if chargingMode == .charging { return AidenteTheme.mint }
        if showState && chargingMode == .pluggedIn { return AidenteTheme.sky }
        if showState { return AidenteTheme.jade }
        return Color(red: 0.62, green: 0.70, blue: 0.78)
    }

    private enum Layout {
        static let cornerRadius: CGFloat = 2
        static let strokeWidth: CGFloat = 0.75
        static let outlineOpacity: CGFloat = 0.5
        static let trackColor = Color(red: 0.84, green: 0.88, blue: 0.92)
        static let contentColor = Color(red: 0.10, green: 0.14, blue: 0.20)
        static let levelAnimation: Animation = .easeInOut(duration: 0.25)
    }

    var body: some View {
        Group {
            if style == .hidden {
                EmptyView()
            } else if style == .appIcon || style == .status {
                HStack(spacing: 3) {
                    Image(systemName: statusSymbol).font(.system(size: 15, weight: .medium))
                    if percentageDisplayLocation != .hidden {
                        Text("\(batteryLevel)%").font(.system(size: 11)).monospacedDigit().lineLimit(1).fixedSize()
                    }
                }
            } else {
                batteryContent
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var statusSymbol: String {
        if style == .appIcon { return "leaf.circle" }
        if chargingMode == .charging { return "bolt.circle.fill" }
        if chargingMode == .pluggedIn { return "powerplug.fill" }
        return adapterConnected ? "battery.50percent" : "battery.25percent"
    }

    private var batteryContent: some View {
        HStack(spacing: BatteryIndicatorLayout.outsideTextSpacing) {
            if shouldShowOutsidePercentage {
                Text("\(batteryLevel)%")
                    .font(.system(size: 11))
                    .monospacedDigit()
            }

            HStack(spacing: BatteryIndicatorLayout.terminalSpacing) {
                batteryBody
                BatteryTerminal(
                    width: BatteryIndicatorLayout.terminalWidth,
                    height: BatteryIndicatorLayout.terminalHeight,
                    cornerRadius: 0.5
                )
            }
        }
        .foregroundStyle(.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = [
            AidenteL10n.t(
                "电池电量 \(batteryLevel)%",
                "Battery level \(batteryLevel)%"
            )
        ]
        switch chargingMode {
        case .charging: parts.append(AidenteL10n.t("正在充电"))
        case .pluggedIn: parts.append(AidenteL10n.t("已接通电源", "Plugged In"))
        case .discharging: break
        }
        if isLowPowerModeEnabled {
            parts.append(AidenteL10n.t("低电量模式", "Low Power Mode"))
        }
        return parts.joined(separator: "，")
    }

    private var batteryBody: some View {
        ZStack {
            Rectangle()
                .fill(style == .macOS26 ? Color.primary.opacity(0.15) : Layout.trackColor)

            GeometryReader { geo in
                Rectangle()
                    .fill(fillColor)
                    .frame(width: fillWidth(usableWidth: geo.size.width))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(Layout.levelAnimation, value: batteryLevel)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: roundedStyle ? 4 : Layout.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: roundedStyle ? 4 : Layout.cornerRadius)
                .strokeBorder(.primary.opacity(Layout.outlineOpacity), lineWidth: Layout.strokeWidth)
        }
        .overlay {
            Group {
                if shouldShowInsidePercentage { insideContent }
                else { chargingGlyph }
            }
            .foregroundStyle(style == .macOS26 ? Color.white : Layout.contentColor)
            .blendMode(style == .macOS26 ? .difference : .normal)
        }
        .compositingGroup()
        .frame(
            width: (shouldShowInsidePercentage ? BatteryIndicatorLayout.insideBodyWidth : BatteryIndicatorLayout.bodyWidth) + (roundedStyle ? 3 : 0),
            height: shouldShowInsidePercentage ? BatteryIndicatorLayout.insideBodyHeight : BatteryIndicatorLayout.bodyHeight
        )
    }

    private var roundedStyle: Bool { style == .macOS27 || style == .iOSNative }

    private func fillWidth(usableWidth: CGFloat) -> CGFloat {
        usableWidth * CGFloat(min(100, max(0, batteryLevel))) / 100
    }

    private var insideContent: some View {
        HStack(spacing: 0.5) {
            Text(verbatim: "\(batteryLevel)")
                .font(.system(size: batteryLevel >= 100 ? 8.2 : 9, weight: .semibold))
                .monospacedDigit()
                .fixedSize()
            chargingGlyph
        }
        .lineLimit(1)
        .fixedSize()
    }

    @ViewBuilder
    private var chargingGlyph: some View {
        if chargingMode == .charging {
            Image(systemName: "bolt.fill")
                .resizable().scaledToFit().frame(width: 3.5, height: 6)
        } else if chargingMode == .pluggedIn {
            Image(systemName: "powerplug.fill")
                .resizable().scaledToFit().frame(width: 4.2, height: 6)
        }
    }
}

struct BatteryTerminal: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: cornerRadius,
            topTrailingRadius: cornerRadius
        )
        .fill(.primary)
        .frame(width: width, height: height)
        .opacity(0.55)
    }
}
