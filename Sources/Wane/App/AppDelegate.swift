#if canImport(AppKit) && canImport(SwiftUI) && canImport(Combine)
import AppKit
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let manager = ProviderManager()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        manager.registerProvider(ClaudeProvider())
        manager.registerProvider(CursorProvider())
        manager.registerProvider(CodexProvider())

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = MoonRenderer.render(percentage: 100, tintColor: .white)
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PopoverView(manager: manager))

        manager.$selectedProviderId
            .combineLatest(manager.$snapshots)
            .receive(on: RunLoop.main)
            .sink { [weak self] selectedProviderId, snapshots in
                self?.updateStatusBarIcon(selectedProviderId: selectedProviderId, snapshots: snapshots)
            }
            .store(in: &cancellables)

        Task { @MainActor in
            await manager.detectProviders()
            await manager.refreshAll()
            manager.startPolling()
        }
    }

    private func updateStatusBarIcon(selectedProviderId: String?, snapshots: [String: UsageSnapshot]) {
        guard
            let selectedProviderId,
            let snapshot = snapshots[selectedProviderId],
            let config = ProviderConfig.all.first(where: { $0.id == selectedProviderId })
        else {
            statusItem.button?.image = MoonRenderer.render(percentage: 100, tintColor: .white)
            return
        }

        statusItem.button?.image = MoonRenderer.render(
            percentage: snapshot.remainingPercentage,
            tintColor: NSColor(hex: config.tintHex)
        )
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Wane", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func refresh() {
        Task { @MainActor in
            await manager.refreshAll()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
#else
import Foundation

final class AppDelegate: NSObject {}
#endif
