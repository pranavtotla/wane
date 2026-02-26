#if canImport(AppKit) && canImport(SwiftUI) && canImport(Combine)
import AppKit
import Combine
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let manager = ProviderManager()
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        manager.registerProvider(ClaudeProvider())
        manager.registerProvider(CursorProvider())
        manager.registerProvider(CodexProvider())

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: "Wane")
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 480)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PopoverView(manager: manager))

        // Update status bar text when data changes
        manager.$selectedProviderId
            .combineLatest(manager.$snapshots)
            .receive(on: RunLoop.main)
            .sink { [weak self] selectedId, snapshots in
                self?.updateStatusBar(selectedId: selectedId, snapshots: snapshots)
            }
            .store(in: &cancellables)

        Task { @MainActor in
            await manager.detectProviders()
            await manager.refreshAll()
            manager.startPolling()
        }
    }

    private func updateStatusBar(selectedId: String?, snapshots: [String: UsageSnapshot]) {
        guard let button = statusItem.button else { return }

        guard let id = selectedId,
              let snapshot = snapshots[id] else {
            button.title = ""
            return
        }

        let pct = Int(snapshot.remainingPercentage)
        button.title = " \(pct)%"
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
            return
        }

        if popover.isShown {
            closePopover()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
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
