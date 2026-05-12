import UIKit
import Messages
import SwiftUI
import EventKit

/// iMessage App Extension principal class.
/// Lives in the app tray at the bottom of every iMessage conversation.
/// Compact presentation: toggle + paste-and-process.
/// Expanded presentation: full review queue.
class MessagesViewController: MSMessagesAppViewController {

    private var hostingController: UIHostingController<MessageExtensionView>?
    private let calendarStore = EKEventStore()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        presentView()
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        // Refreshes view each time the user enters a conversation
        presentView()
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        hostingController?.rootView = makeView()
    }

    // MARK: - View

    private func presentView() {
        if let existing = hostingController {
            existing.rootView = makeView()
            return
        }

        let hc = UIHostingController(rootView: makeView())
        hostingController = hc

        addChild(hc)
        hc.view.frame = view.bounds
        hc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hc.view)
        hc.didMove(toParent: self)
    }

    private func makeView() -> MessageExtensionView {
        MessageExtensionView(
            calendarStore: calendarStore,
            isCompact: presentationStyle == .compact,
            onExpand: { [weak self] in
                self?.requestPresentationStyle(.expanded)
            },
            onCollapse: { [weak self] in
                self?.requestPresentationStyle(.compact)
            }
        )
    }
}
