import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let cliService = SkillsCLIService()
        let installedCatalog = InstalledSkillsCatalogService()
        let customCatalog = CustomSkillsCatalogService()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "myAgentSkills")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.toolTip = "myAgentSkills"
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 940, height: 720)
        popover.contentViewController = PopoverViewController(
            cliService: cliService,
            installedCatalog: installedCatalog,
            customCatalog: customCatalog
        )
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
        }
    }
}
