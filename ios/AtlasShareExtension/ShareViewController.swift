import UIKit
import Social
import SwiftUI
import EventKit
import UniformTypeIdentifiers

/// Principal class for the Share Extension.
/// Activated when the user taps Share in WhatsApp, Messenger, Instagram, or any other app.
class ShareViewController: UIViewController {

    private var hostingController: UIHostingController<ShareView>?
    private var extractedText: String = ""
    private var sourceApp: QueuedMessage.MessageSource = .unknown

    override func viewDidLoad() {
        super.viewDidLoad()
        detectSource()
        extractText { [weak self] text in
            guard let self else { return }
            self.extractedText = text ?? ""
            DispatchQueue.main.async { self.presentSwiftUI() }
        }
    }

    // MARK: - Source detection

    private func detectSource() {
        guard let host = extensionContext?.inputItems.first as? NSExtensionItem,
              let bundleId = host.userInfo?["NSExtensionItemSourceBundleIdentifierKey"] as? String else {
            return
        }
        switch bundleId {
        case let s where s.contains("whatsapp"):   sourceApp = .whatsApp
        case let s where s.contains("facebook"),
             let s where s.contains("messenger"):  sourceApp = .messenger
        case let s where s.contains("instagram"):  sourceApp = .instagram
        case let s where s.contains("messages"):   sourceApp = .iMessage
        default: sourceApp = .unknown
        }
    }

    // MARK: - Text extraction

    private func extractText(completion: @escaping (String?) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else {
            completion(nil); return
        }

        let providers = item.attachments ?? []

        // Try plain text first
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { data, _ in
                    if let text = data as? String {
                        completion(text); return
                    }
                    if let url = data as? URL,
                       let text = try? String(contentsOf: url, encoding: .utf8) {
                        completion(text); return
                    }
                    completion(nil)
                }
                return
            }
        }

        // Fallback: attributed string
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.rtf.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.rtf.identifier) { data, _ in
                    if let data = data as? Data,
                       let attr = try? NSAttributedString(data: data, options: [:], documentAttributes: nil) {
                        completion(attr.string); return
                    }
                    completion(nil)
                }
                return
            }
        }

        completion(nil)
    }

    // MARK: - SwiftUI hosting

    private func presentSwiftUI() {
        let store = EKEventStore()
        let view = ShareView(
            messageText: extractedText,
            source: sourceApp,
            calendarStore: store,
            onDone: { [weak self] in self?.done() },
            onCancel: { [weak self] in self?.cancel() }
        )

        let hc = UIHostingController(rootView: view)
        hostingController = hc
        addChild(hc)
        hc.view.frame = view_bounds()
        view.addSubview(hc.view)
        hc.didMove(toParent: self)

        hc.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hc.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            hc.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            hc.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
        ])
    }

    private func view_bounds() -> CGRect { view.bounds }

    private func done() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "AtlasShare", code: 0))
    }
}
