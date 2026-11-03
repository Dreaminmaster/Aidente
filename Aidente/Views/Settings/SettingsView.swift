import AppKit
import Defaults
import SwiftUI
import smc_power

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case menuBar = "MenuBar"
    case dashboard = "Dashboard"
    case charging = "Charging"
    case automation = "Automation"
    case advanced = "Advanced"
    case diagnostics = "Diagnostics"
    case about = "About"

    var id: String { rawValue }

    init?(urlValue: String) {
        guard let tab = Self.allCases.first(where: {
            $0.rawValue.lowercased() == urlValue.lowercased()
        }) else {
            return nil
        }
        self = tab
    }
    
    var title: String {
        switch self {
        case .menuBar: AidenteL10n.t("菜单栏", "Menu Bar")
        case .general: AidenteL10n.t("通用")
        case .dashboard: AidenteL10n.t("弹出窗口", "Popover")
        case .charging: AidenteL10n.t("充电管理")
        case .automation: AidenteL10n.t("计划与自动化")
        case .advanced: AidenteL10n.t("高级")
        case .diagnostics: AidenteL10n.t("诊断")
        case .about: AidenteL10n.t("关于")
        }
    }

    var icon: String {
        switch self {
        case .menuBar: return "menubar.rectangle"
        case .general:
            return "gearshape.fill"
        case .dashboard:
            return "gauge.with.dots.needle.67percent"
        case .charging:
            return "battery.100.bolt"
        case .automation:
            return "calendar.badge.clock"
        case .advanced:
            return "slider.horizontal.3"
        case .diagnostics:
            return "waveform.badge.magnifyingglass"
        case .about:
            return "heart.text.square.fill"
        }
    }

    var colors: [Color] {
        switch self {
        case .menuBar: AidenteTheme.generalColors
        case .general: AidenteTheme.generalColors
        case .dashboard: AidenteTheme.dashboardColors
        case .charging: AidenteTheme.chargingColors
        case .automation: AidenteTheme.automationColors
        case .advanced: AidenteTheme.advancedColors
        case .diagnostics: AidenteTheme.dashboardColors
        case .about: AidenteTheme.aboutColors
        }
    }
}

struct SettingsView: View {
    @Default(.appLanguage) private var appLanguage
    @State private var selectedTab: SettingsTab

    private let capabilities: DeviceCapabilities
    private let chargeManager: ChargeManager
    private let diagnosticCenter: DiagnosticCenter
    private let updateService: UpdateService

    init(
        capabilities: DeviceCapabilities,
        chargeManager: ChargeManager,
        diagnosticCenter: DiagnosticCenter,
        updateService: UpdateService,
        initialTab: SettingsTab = .general
    ) {
        self.capabilities = capabilities
        self.chargeManager = chargeManager
        self.diagnosticCenter = diagnosticCenter
        self.updateService = updateService
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section(AidenteL10n.t("电池保养", "Battery Care")) {
                    navigationRow(.charging)
                    navigationRow(.automation)
                }
                Section(AidenteL10n.t("外观", "Appearance")) {
                    navigationRow(.dashboard)
                    navigationRow(.menuBar)
                }
                Section(AidenteL10n.t("应用", "Application")) {
                    navigationRow(.general)
                    navigationRow(.advanced)
                    navigationRow(.diagnostics)
                    navigationRow(.about)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Aidente")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            detailContent.navigationTitle(selectedTab.title)
        }
        .frame(minWidth: 960, minHeight: 640)
        .tint(AidenteTheme.jade)
        .onAppear { updateWindowTitle() }
        .onChange(of: appLanguage) { _, _ in updateWindowTitle() }
    }

    private func navigationRow(_ tab: SettingsTab) -> some View {
        Label(tab.title, systemImage: tab.icon).tag(tab)
    }

    @ViewBuilder private var detailContent: some View {
        switch selectedTab {
        case .menuBar: MenuBarSettingsView()
        case .general: GeneralSettingsView()
        case .dashboard: DashboardSettingsView()
        case .charging: ChargingSettingsView(capabilities: capabilities, chargeManager: chargeManager)
        case .automation: AutomationSettingsView()
        case .advanced: AdvancedSettingsView()
        case .diagnostics: DiagnosticsSettingsView(diagnosticCenter: diagnosticCenter)
        case .about: AboutSettingsView(updateService: updateService)
        }
    }

    private func updateWindowTitle() {
        DispatchQueue.main.async {
            NSApp.keyWindow?.title = AidenteL10n.t(
                "Aidente 设置",
                "Aidente Settings"
            )
        }
    }
}
