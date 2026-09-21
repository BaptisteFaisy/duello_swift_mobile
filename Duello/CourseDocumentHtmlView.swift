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
        webView.loadHTMLString(Self.document(html, selectable: selectable), baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onMessage = onMessage
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

        init(onMessage: ((String) -> Void)?) {
            self.onMessage = onMessage
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
    /// sont insérés juste après l'ouverture de `<head>`.
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
        return insert(bridge + policy, afterHeadOf: html)
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

// MARK: - Document HTML d'une photo

/// Documents HTML autonomes affichés par `CtdHtmlDocumentView`.
///
/// Porté de `courseImageHtml` (`src/utils/courseDocument.ts`). Le repère de
/// progression de classe (`class-progress-marker`) et la commande
/// `duello-course-positioning` ne sont pas portés : ils appartiennent au
/// lecteur « Mon cours » de `SubjectsScreen.tsx`, hors de ce lot.
enum CtdDocumentHtml {
    /// Photo de cours ou de TD : le document affiche l'image en base64 et
    /// prévient le lecteur (`ready`, `error`), comme côté Expo.
    static func imageHtml(base64: String, mimeType: CtdMimeType) -> String {
        """
        <!doctype html>
        <html lang="fr">
          <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=4, user-scalable=yes" />
            <style>
              html, body { margin: 0; min-height: 100%; background: #e9e9e7; }
              body { padding: 12px; box-sizing: border-box; }
              #course-image { display: block; width: 100%; height: auto; background: white; box-shadow: 0 2px 10px rgba(10,13,12,.14); }
              #status { min-height: 180px; display: flex; align-items: center; justify-content: center; padding: 24px; box-sizing: border-box; color: #555b58; text-align: center; font: 600 15px -apple-system, BlinkMacSystemFont, sans-serif; }
            </style>
          </head>
          <body>
            <div id="status">Préparation du cours…</div>
            <img id="course-image" alt="Photo du cours" src="data:\(mimeType.rawValue);base64,\(base64)" />
            <script>
              (function () {
                var image = document.getElementById('course-image');
                var status = document.getElementById('status');
                var notify = function (type) {
                  if (window.ReactNativeWebView) {
                    window.ReactNativeWebView.postMessage(JSON.stringify({ type: type }));
                  }
                };
                var displayed = function () {
                  if (status) { status.remove(); }
                  notify('ready');
                };
                // Une image en base64 peut déjà être décodée quand ce script
                // s'exécute : son événement de chargement ne serait alors
                // jamais émis et le cours resterait sur son écran d'attente.
                if (image.complete && image.naturalWidth > 0) {
                  displayed();
                } else {
                  image.addEventListener('load', displayed);
                }
                image.addEventListener('error', function () {
                  status.textContent = 'La photo du cours n’a pas pu être affichée.';
                  notify('error');
                });
              })();
            </script>
          </body>
        </html>
        """
    }
}
