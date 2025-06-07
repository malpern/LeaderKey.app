import SwiftUI
import AppKit

/// A helper to present a SwiftUI view in an NSPopover anchored to an NSView.
struct PopoverPresenter<Content: View>: NSViewRepresentable {
    @Binding var isPresented: Bool
    let content: () -> Content
    let preferredEdge: NSRectEdge
    let anchorView: NSView?

    class Coordinator: NSObject {
        var popover: NSPopover?
        var hostingController: NSViewController?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.updatePopover(context: context, anchorView: anchorView, nsView: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            self.updatePopover(context: context, anchorView: anchorView, nsView: nsView)
        }
    }

    private func updatePopover(context: Context, anchorView: NSView?, nsView: NSView) {
        if isPresented {
            if context.coordinator.popover == nil {
                let popover = NSPopover()
                popover.behavior = .transient
                let hosting = NSHostingController(rootView: content())
                popover.contentViewController = hosting
                context.coordinator.popover = popover
                context.coordinator.hostingController = hosting
                if let anchor = anchorView ?? nsView.superview {
                    popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: preferredEdge)
                }
            } else {
                // Update content if already presented
                if let hosting = context.coordinator.hostingController as? NSHostingController<Content> {
                    hosting.rootView = content()
                }
            }
        } else {
            context.coordinator.popover?.close()
            context.coordinator.popover = nil
            context.coordinator.hostingController = nil
        }
    }
}