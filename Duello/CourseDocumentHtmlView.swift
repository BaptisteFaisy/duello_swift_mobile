import SwiftUI
import WebKit

/// Vue de document HTML, portée de `src/components/HtmlDocumentView.native.tsx`.
///
/// L'app Expo monte une WebView `react-native-webview` et les documents qu'elle
/// reçoit appellent `window.ReactNativeWebView.postMessage`. Le pont iOS
/// conserve ce contrat : un script injecté en tête de document redirige
/// `ReactNativeWebView.postMessage` vers le canal `duello`, si bien que les
/// documents HTML restent ceux d'Expo (voir `CtdDocumentHtml`).
struct CtdHtmlDocumentView: UIViewRepresentable {
    let html: String
    /// `selectable` : sans sélection, le document interdit aussi le menu
    /// contextuel (`withSelectionPolicy`).
    var selectable: Bool = true
    /// `command` (`HtmlDocumentView.native.tsx:64-74`) : message JSON
    /// `duello-course-positioning` réinjecté dans le document à chaque
    /// changement, sans recharger le HTML.
    var command: String? = nil
    /// Messages du document, en JSON, comme `onMessage` côté Expo.
    var onMessage: ((String) -> Void)? = nil

    /// Nom du canal `WKScriptMessageHandler`.
    static let bridgeName = "duello"

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: Self.bridgeName)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.loadedHTML = html
        context.coordinator.command = command
        webView.loadHTMLString(Self.document(html, selectable: selectable), baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onMessage = onMessage
        // `useEffect(() => dispatchCommand(), [dispatchCommand])` : la bascule du
        // mode repère repart au document sans recharger le HTML.
        if context.coordinator.command != command {
            context.coordinator.command = command
            context.coordinator.dispatchCommand(in: webView)
        }
        // `source={{ html }}` : un nouveau document (import, révision) recharge
        // la WebView, comme le natif RN.
        if context.coordinator.loadedHTML != html {
            context.coordinator.loadedHTML = html
            webView.loadHTMLString(Self.document(html, selectable: selectable), baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onMessage: onMessage)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: bridgeName)
    }

    /// Reçoit les messages du document et les rend au lecteur.
    final class Coordinator: NSObject, WKScriptMessageHandler {
        var onMessage: ((String) -> Void)?
        /// Dernier HTML chargé : un nouveau document recharge la WebView.
        var loadedHTML: String?
        /// Commande `duello-course-positioning` courante, réinjectée à la bascule.
        var command: String?

        init(onMessage: ((String) -> Void)?) {
            self.onMessage = onMessage
        }

        /// `dispatchCommand` (`HtmlDocumentView.native.tsx:65-70`) : republie la
        /// commande dans le document via un `MessageEvent`, sans recharger le
        /// HTML — c'est le canal qu'écoute le script de position.
        func dispatchCommand(in webView: WKWebView) {
            guard let command else { return }
            let script = "window.dispatchEvent(new MessageEvent('message', { data: \(command) })); true;"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == CtdHtmlDocumentView.bridgeName,
                  let text = message.body as? String
            else { return }
            onMessage?(text)
        }
    }

    /// `withSelectionPolicy` + pont `ReactNativeWebView` : les deux scripts
    /// sont insérés juste après l'ouverture de `<head>` ; le pont du prof IA
    /// (`insertProfBridge`) rejoint la fin de `<body>`.
    static func document(_ html: String, selectable: Bool) -> String {
        let bridge = """
        <script>
        window.ReactNativeWebView = {
          postMessage: function (payload) {
            window.webkit.messageHandlers.\(bridgeName).postMessage(payload);
          }
        };
        </script>
        """
        var policy = ""
        if !selectable {
            policy = """
            <style id="duello-selection-policy">
            html, body, body * {
              -webkit-user-select: none !important;
              user-select: none !important;
              -webkit-touch-callout: none !important;
            }
            </style>
            """
        }
        return insertProfBridge(insert(bridge + policy, afterHeadOf: html))
    }

    /// Insère le pont « Expliquer ce passage » en fin de `<body>` : le script
    /// pose son bouton sur `document.body`, qui doit donc déjà exister. La
    /// source injecte le pont de même, dans le corps du document
    /// (`courseDocumentPdf.ts`, `mathDocument.ts`).
    static func insertProfBridge(_ html: String) -> String {
        let script = "<script>\n\(profSelectionBridgeScript())\n</script>"
        guard let bodyEnd = html.range(of: "</body>", options: [.caseInsensitive, .backwards]) else {
            return html + script
        }
        return String(html[..<bodyEnd.lowerBound]) + script + String(html[bodyEnd.lowerBound...])
    }

    /// Insère un bloc en tête de document ; sans `<head>`, le bloc précède le
    /// document, comme le repli d'Expo.
    static func insert(_ injected: String, afterHeadOf html: String) -> String {
        guard let headStart = html.range(of: "<head", options: [.caseInsensitive]),
              let headEnd = html[headStart.upperBound...].firstIndex(of: ">")
        else {
            return injected + html
        }
        let cut = html.index(after: headEnd)
        return String(html[..<cut]) + injected + String(html[cut...])
    }
}
