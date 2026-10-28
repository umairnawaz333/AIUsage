import AppKit
import SwiftUI

/// Owns the borderless panel that sits over the notch and expands on hover.
@MainActor
final class NotchController {
    let model = IslandModel()
    private let store: UsageStore
    private var panel: NSPanel?
    private var monitors: [Any] = []
    private var pendingExpand: DispatchWorkItem?

    /// Where the island's left edge sits (notch left edge) and the top of the screen, in screen coordinates.
    private var originX: CGFloat = 0
    private var screenTop: CGFloat = 0

    /// Room around the island so the detail box and its shadow are never clipped.
    static let margin: CGFloat = 24
    /// Extra room on the left, for when the detail box is wider than the wing (screens without a notch).
    static let leftRoom = NotchGeometry.detailSize.width + margin
    /// Widest the collapsed wing gets, with room to spare.
    static let maxWingWidth: CGFloat = 160

    init(store: UsageStore) {
        self.store = store
    }

    func show() {
        let host = FirstMouseHostingView(rootView:
            IslandView(model: model, store: store).padding(.leading, Self.leftRoom))
        // The panel's frame is set by layout(); don't let the SwiftUI content resize it.
        host.sizingOptions = []
        let panel = KeyablePanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = true
        panel.contentView = host
        self.panel = panel

        layout()
        panel.orderFrontRegardless()

        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            Task { @MainActor in self?.handleMouse(NSEvent.mouseLocation) }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handleMouse(NSEvent.mouseLocation)
            return event
        }) {
            monitors.append(local)
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.layout() }
        }
    }

    /// Places the panel on the screen with a notch, or centred at the top of the main screen.
    func layout() {
        guard let panel,
              let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
        else { return }
        let frame = screen.frame

        var geometry: NotchGeometry
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            geometry = NotchGeometry(notchWidth: frame.width - left.width - right.width,
                                     height: screen.safeAreaInsets.top)
            originX = frame.minX + left.width
        } else {
            let menuBar = frame.maxY - screen.visibleFrame.maxY
            geometry = NotchGeometry(notchWidth: 0, height: menuBar > 0 ? menuBar : 24)
            originX = frame.midX - 40
        }
        model.geometry = geometry
        screenTop = frame.maxY

        let width = Self.leftRoom + geometry.notchWidth + Self.maxWingWidth + Self.margin
        let height = geometry.height + NotchGeometry.detailSize.height + Self.margin
        panel.setFrame(CGRect(x: originX - Self.leftRoom, y: screenTop - height, width: width, height: height),
                       display: true)
    }

    private var collapsedRect: CGRect {
        let size = model.collapsedSize
        return CGRect(x: originX, y: screenTop - model.geometry.height, width: size.width, height: model.geometry.height)
    }

    /// The strip plus the detail box hanging under it.
    private var expandedRect: CGRect {
        let detail = NotchGeometry.detailSize
        let box = CGRect(x: originX + model.detailOffsetX, y: screenTop - model.geometry.height - detail.height,
                         width: model.detailWidth, height: detail.height)
        return collapsedRect.union(box)
    }

    private func handleMouse(_ point: CGPoint) {
        if model.expanded {
            if !expandedRect.insetBy(dx: -8, dy: -8).contains(point) { collapse() }
        } else if collapsedRect.insetBy(dx: 0, dy: -2).contains(point) {
            guard pendingExpand == nil else { return }
            // A short dwell so sweeping the pointer across the menu bar doesn't pop it open.
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.pendingExpand = nil
                if self.collapsedRect.insetBy(dx: 0, dy: -2).contains(NSEvent.mouseLocation) { self.expand() }
            }
            pendingExpand = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        } else {
            pendingExpand?.cancel()
            pendingExpand = nil
        }
    }

    func expand() {
        model.expanded = true
        panel?.ignoresMouseEvents = false
    }

    func collapse() {
        model.expanded = false
        panel?.ignoresMouseEvents = true
    }
}

/// Borderless panels refuse key status by default, which can swallow clicks on SwiftUI buttons.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Lets buttons in the non-activating panel respond to the first click.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
