import AppKit
import Defaults
import SwiftUI

@MainActor
final class StatusBarManager: NSObject, NSPopoverDelegate, NSWindowDelegate {
    private let statusItem: NSStatusItem
    private let viewModel: MenuViewModel
    private let displayState: MenuBarDisplayState
    private var statusHosting: NSHostingView<AnyView>?
    private let settingsWindowController: SettingsWindowController
    private let popover = NSPopover()
    private var displayObservation: Task<Void, Never>?
    private var powerWidthObservation: Task<Void, Never>?
    private var previewWindow: NSWindow?
    private var dashboardWindow: NSWindow?

    init(
        viewModel: MenuViewModel,
        settingsWindowController: SettingsWindowController
    ) {
        self.viewModel = viewModel
        self.displayState = MenuBarDisplayState(viewModel: viewModel)
        self.settingsWindowController = settingsWindowController
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        super.init()

        configurePopoverShell()
        setupPersistentHostingView()
        startDisplayObservation()
    }

    private func configurePopoverShell() {
        popover.contentSize = NSSize(width: 408, height: 720)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    private func preparePopoverContentIfNeeded() {
        guard popover.contentViewController == nil else { return }

        let rootView = makeDashboardRootView()
        popover.contentViewController = NSHostingController(rootView: rootView)
        popover.contentViewController?.view.wantsLayer = true
        popover.contentViewController?.view.layer?.cornerRadius = 15
        popover.contentViewController?.view.layer?.masksToBounds = true
    }

    private func makeDashboardRootView() -> DashboardPopoverView {
        DashboardPopoverView(
            viewModel: viewModel,
            onOpenSettings: { [weak self] tab in
                guard let self else { return }
                self.popover.performClose(nil)
                self.previewWindow?.close()
                self.dashboardWindow?.close()
                self.settingsWindowController.showSettings(tab: tab)
            },
            onQuit: { [weak self] in
                self?.viewModel.quit()
            }
        )
    }

    private func setupPersistentHostingView() {
        guard let button = statusItem.button else { return }

        let rootView = AnyView(StatusBarContentView(displayState: displayState).allowsHitTesting(false))
        let hosting = NSHostingView(rootView: rootView)
        statusHosting = hosting

        button.subviews.forEach { $0.removeFromSuperview() }
        button.title = ""
        button.image = nil
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        hosting.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: button.topAnchor, constant: 1),
            hosting.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -1),
            hosting.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: BatteryIndicatorLayout.statusInset),
            hosting.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -BatteryIndicatorLayout.statusInset),
        ])
    }

    private func startDisplayObservation() {
        displayObservation = Task { [weak self] in
            for await _ in Defaults.updates(
                [.menuBarIconStyle, .menuBarMetrics, .menuBarItemSpacing,
                 .menuBarUpdateInterval, .menuBarLowPowerColor, .appLanguage,
                 .showBatteryStateInStatusIcon, .menuBarReadoutStyle,
                 .batteryPercentageDisplayLocation], initial: true
            ) {
                guard let self else { return }
                self.powerWidthObservation?.cancel()
                self.powerWidthObservation = Task { [weak self] in
                    while !Task.isCancelled {
                        guard let self else { return }
                        self.displayState.snapshot = MenuBarSnapshot(viewModel: self.viewModel)
                        await Task.yield()
                        self.updateStatusItemLength()
                        // Read-only sampling: never enables or repairs charging control.
                        self.viewModel.requestMenuBarSample()
                        let seconds = max(2, min(20, Defaults[.menuBarUpdateInterval]))
                        try? await Task.sleep(for: .seconds(seconds))
                    }
                }
            }
        }
    }

    private func updateStatusItemLength() {
        let hasIcon = Defaults[.menuBarIconStyle] != .hidden
        let hasMetrics = !MenuBarMetric.selected(from: Defaults[.menuBarMetrics]).isEmpty
        let hasLegacyPower = Defaults[.menuBarReadoutStyle] != .batteryPercentage
        statusItem.isVisible = hasIcon || hasMetrics || hasLegacyPower
        guard statusItem.isVisible, let hosting = statusHosting else { return }
        hosting.invalidateIntrinsicContentSize()
        hosting.layoutSubtreeIfNeeded()
        statusItem.length = ceil(hosting.fittingSize.width) + BatteryIndicatorLayout.statusInset * 2
    }

    @objc private func openMenuBarSettings() {
        popover.performClose(nil)
        settingsWindowController.showSettings(tab: .menuBar)
    }

    @objc private func openDashboard() { showDashboardWindow() }
    @objc private func quitFromQuickMenu() { viewModel.quit() }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            switch Defaults[.menuBarRightClick] {
            case .popover: break
            case .settings:
                openMenuBarSettings()
                return
            case .contextMenu:
                let menu = NSMenu()
                for (title, action) in [
                    (AidenteL10n.t("仪表盘", "Dashboard"), #selector(openDashboard)),
                    (AidenteL10n.t("菜单栏设置", "Menu Bar Settings"), #selector(openMenuBarSettings)),
                    (AidenteL10n.t("退出 Aidente", "Quit Aidente"), #selector(quitFromQuickMenu))
                ] {
                    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
                    item.target = self
                    menu.addItem(item)
                }
                statusItem.menu = menu
                sender.performClick(nil)
                statusItem.menu = nil
                return
            }
        }

        if popover.isShown {
            popover.performClose(sender)
            return
        }

        if let dashboardWindow, dashboardWindow.isVisible {
            dashboardWindow.close()
            Task { [weak self, weak sender] in
                await Task.yield()
                guard let self, let sender else { return }
                self.presentPopover(relativeTo: sender)
            }
            return
        }

        presentPopover(relativeTo: sender)
    }

    private func presentPopover(relativeTo sender: NSStatusBarButton) {
        preparePopoverContentIfNeeded()
        viewModel.menuWillOpen()
        popover.show(
            relativeTo: sender.bounds,
            of: sender,
            preferredEdge: .minY
        )
        popover.contentViewController?.view.window?.makeKey()
    }

    func showDashboardWindow() {
        if let dashboardWindow {
            NSApp.activate(ignoringOtherApps: true)
            dashboardWindow.makeKeyAndOrderFront(nil)
            dashboardWindow.orderFrontRegardless()
            return
        }

        if popover.isShown {
            popover.performClose(nil)
            Task { [weak self] in
                await Task.yield()
                self?.presentDashboardWindow()
            }
            return
        }

        presentDashboardWindow()
    }

    private func presentDashboardWindow() {
        guard dashboardWindow == nil else { return }

        let hostingController = NSHostingController(rootView: makeDashboardRootView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = AidenteL10n.t("Aidente 主菜单", "Aidente Dashboard")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 408, height: 720))
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        hostingController.view.wantsLayer = true
        hostingController.view.layer?.cornerRadius = 15
        hostingController.view.layer?.masksToBounds = true

        dashboardWindow = window
        viewModel.menuWillOpen()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func showPopoverForPreview() {
        guard let button = statusItem.button, !popover.isShown else { return }
        NSApp.activate(ignoringOtherApps: true)
        preparePopoverContentIfNeeded()
        viewModel.menuWillOpen()
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )
        popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
    }

    func showWindowForPreview() {
        guard previewWindow == nil else { return }

        let hostingController = NSHostingController(rootView: makeDashboardRootView())
        let panel = AidentePreviewPanel(contentViewController: hostingController)
        panel.styleMask = [.borderless]
        panel.setContentSize(NSSize(width: 408, height: 720))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        if let screen = NSScreen.screens.first {
            let visibleFrame = screen.visibleFrame
            panel.setFrameOrigin(
                NSPoint(
                    x: visibleFrame.midX - 204,
                    y: visibleFrame.midY - 360
                )
            )
        } else {
            panel.center()
        }

        hostingController.view.wantsLayer = true
        hostingController.view.layer?.cornerRadius = 15
        hostingController.view.layer?.masksToBounds = true

        previewWindow = panel
        viewModel.menuWillOpen()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func popoverDidClose(_ notification: Notification) {
        viewModel.menuDidClose()
        Task { [weak self] in
            await Task.yield()
            self?.popover.contentViewController = nil
        }
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            guard let closedWindow = notification.object as? NSWindow else { return }
            if closedWindow === dashboardWindow {
                dashboardWindow = nil
                viewModel.menuDidClose()
            } else if closedWindow === previewWindow {
                previewWindow = nil
                viewModel.menuDidClose()
            }
        }
    }

    deinit {
        displayObservation?.cancel()
        powerWidthObservation?.cancel()
    }
}

private final class AidentePreviewPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

struct StatusBarContentView: View {
    let displayState: MenuBarDisplayState
    @Default(.batteryPercentageDisplayLocation) private var percentageLocation
    @Default(.menuBarReadoutStyle) private var readoutStyle
    @Default(.showBatteryStateInStatusIcon) private var showState
    @Default(.menuBarIconStyle) private var iconStyle
    @Default(.menuBarMetrics) private var metricIDs
    @Default(.menuBarItemSpacing) private var spacing
    @Default(.menuBarLowPowerColor) private var lowPowerColor

    var body: some View {
        let snapshot = displayState.snapshot
        HStack(spacing: CGFloat(max(0, min(20, spacing)))) {
            BatteryIndicatorView(
                batteryLevel: snapshot.percentage, chargingMode: snapshot.chargingMode,
                isLowPowerModeEnabled: lowPowerColor && snapshot.lowPower,
                percentageDisplayLocation: readoutStyle == .systemPower ? .hidden
                    : readoutStyle == .batteryAndPower ? .insideIcon : percentageLocation,
                showState: showState, style: iconStyle, adapterConnected: snapshot.adapterConnected
            )
            if readoutStyle != .batteryPercentage {
                Text(snapshot.power).font(.system(size: 10.5, weight: .semibold)).monospacedDigit()
            }
            ForEach(MenuBarMetric.selected(from: metricIDs)) { metric in
                Label(snapshot.values[metric.id] ?? "—", systemImage: metric.icon)
                    .font(.system(size: 11)).monospacedDigit()
                    .help("\(metric.group) · \(metric.title)")
            }
        }
        .fixedSize().lineLimit(1)
        .help(AidenteL10n.t("电量 \(snapshot.percentage)% · 系统功率 \(snapshot.power)",
                            "Battery \(snapshot.percentage)% · System power \(snapshot.power)"))
    }
}
