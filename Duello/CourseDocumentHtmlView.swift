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

// MARK: - Document HTML d'une photo

/// Documents HTML autonomes affichés par `CtdHtmlDocumentView`.
///
/// Porté de `courseImageHtml` (`src/utils/courseDocument.ts:117-252`), repère de
/// progression de classe (`class-progress-marker`) et commande
/// `duello-course-positioning` compris.
enum CtdDocumentHtml {
    /// Photo de cours ou de TD : le document affiche l'image en base64, le
    /// repère de progression quand il est demandé, et prévient le lecteur
    /// (`ready`, `error`, `position`), comme côté Expo.
    static func imageHtml(
        base64: String,
        mimeType: CtdMimeType,
        positioning: Bool = false,
        initialPosition: Double? = nil
    ) -> String {
        let normalized = normalizedPosition(initialPosition)
        let safeInitial = normalized ?? 0
        let initialScript = normalized == nil ? "null" : String(safeInitial)
        let markerVisible = positioning || normalized != nil
        return """
        <!doctype html>
        <html lang="fr">
          <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=4, user-scalable=yes" />
            <style>
              html, body { margin: 0; min-height: 100%; background: #e9e9e7; }
              body { position: relative; padding: \(positioning ? "50vh 12px" : "12px"); box-sizing: border-box; }
              #course-image { display: block; width: 100%; height: auto; background: white; box-shadow: 0 2px 10px rgba(10,13,12,.14); }
              #status { min-height: 180px; display: flex; align-items: center; justify-content: center; padding: 24px; box-sizing: border-box; color: #555b58; text-align: center; font: 600 15px -apple-system, BlinkMacSystemFont, sans-serif; }
              #class-progress-marker {
                display: \(markerVisible ? "block" : "none");
                position: \(positioning ? "fixed" : "absolute");
                z-index: 20;
                right: 0;
                top: 50%;
                width: 42px;
                height: 3px;
                background: #d32020;
                box-shadow: 0 1px 4px rgba(120, 0, 0, .28);
                transform: translateY(-50%);
                pointer-events: none;
              }
              #class-progress-marker::before {
                content: '';
                position: absolute;
                left: -8px;
                top: -5px;
                border-top: 7px solid transparent;
                border-bottom: 7px solid transparent;
                border-right: 9px solid #d32020;
              }
            </style>
          </head>
          <body>
            <div id="status">Préparation du cours…</div>
            <img id="course-image" alt="Photo du cours" src="data:\(mimeType.rawValue);base64,\(base64)" />
            <div id="class-progress-marker" aria-hidden="true"></div>
            <script>
              (function () {
                var image = document.getElementById('course-image');
                var status = document.getElementById('status');
                var notify = function (type, detail) {
                  if (window.ReactNativeWebView) {
                    var payload = { type: type };
                    if (detail) { for (var key in detail) { payload[key] = detail[key]; } }
                    window.ReactNativeWebView.postMessage(JSON.stringify(payload));
                  }
                };
                var currentPosition = function () {
                  var height = Math.max(1, image.offsetHeight);
                  var markerPosition = window.scrollY + window.innerHeight / 2;
                  return Math.min(1, Math.max(0, (markerPosition - image.offsetTop) / height));
                };
                var contentReady = false;
                var positioningEnabled = \(positioning ? "true" : "false");
                var desiredPosition = \(initialScript);
                var applyPositioning = function (resetToTop) {
                  var marker = document.getElementById('class-progress-marker');
                  document.body.style.padding = positioningEnabled ? '50vh 12px' : '12px';
                  marker.style.display = (positioningEnabled || desiredPosition !== null) ? 'block' : 'none';
                  marker.style.position = positioningEnabled ? 'fixed' : 'absolute';
                  marker.style.top = positioningEnabled
                    ? '50%'
                    : (image.offsetTop + (desiredPosition === null ? 0 : desiredPosition) * image.offsetHeight) + 'px';
                  if (resetToTop) {
                    requestAnimationFrame(function () { window.scrollTo(0, 0); });
                    return;
                  }
                  if (!contentReady || !positioningEnabled) return;
                  requestAnimationFrame(function () {
                    var markerPosition = image.offsetTop + (desiredPosition === null ? 0 : desiredPosition) * image.offsetHeight;
                    window.scrollTo(0, Math.max(0, markerPosition - window.innerHeight / 2));
                    notify('position', { position: currentPosition() });
                  });
                };
                window.addEventListener('message', function (event) {
                  var command = event.data;
                  if (!command || command.type !== 'duello-course-positioning') return;
                  var wasPositioningEnabled = positioningEnabled;
                  positioningEnabled = command.positioning === true;
                  desiredPosition = (typeof command.position === 'number' && isFinite(command.position))
                    ? Math.min(1, Math.max(0, command.position))
                    : null;
                  applyPositioning(wasPositioningEnabled && !positioningEnabled);
                });
                var positionFrame = 0;
                window.addEventListener('scroll', function () {
                  if (!contentReady || !positioningEnabled) return;
                  if (positionFrame) cancelAnimationFrame(positionFrame);
                  positionFrame = requestAnimationFrame(function () {
                    positionFrame = 0;
                    notify('position', { position: currentPosition() });
                  });
                }, { passive: true });
                var displayed = function () {
                  if (status) { status.remove(); }
                  contentReady = true;
                  applyPositioning(false);
                  notify('ready', {});
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
                  notify('error', {});
                });
              })();
            </script>
          </body>
        </html>
        """
    }

    /// `normalizedCoursePosition` (`courseDocument.ts:32-36`).
    private static func normalizedPosition(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return min(1, max(0, value))
    }
}
