import Foundation

// MARK: - Document HTML d'une photo

/// Documents HTML autonomes affichés par `CtdHtmlDocumentView`.
///
/// Porté de `courseImageHtml` (`src/utils/courseDocument.ts:117-252`), repère de
/// progression de classe (`class-progress-marker`), commande
/// `duello-course-positioning` et pont « Expliquer cette photo »
/// (`profExplain`, `profExplainImageScript`) compris.
///
/// Découpé en en-tête, corps et script pour tenir la limite de 50 lignes par
/// fonction : chaque morceau reprend mot pour mot la chaîne d'origine, la
/// concaténation rendant le document identique à celui d'Expo.
enum CtdDocumentHtml {
    /// Photo de cours ou de TD : le document affiche l'image en base64, le
    /// repère de progression quand il est demandé, et prévient le lecteur
    /// (`ready`, `error`, `position`), comme côté Expo.
    ///
    /// `profExplain` : le pont du prof IA (`profExplainImageScript`) est injecté
    /// et le bouton « Expliquer cette photo » est posé à l'affichage
    /// (`profExplain: onProfExplainImage !== undefined`,
    /// `CourseDocumentViewer.native.tsx:87-92`).
    static func imageHtml(
        base64: String,
        mimeType: CtdMimeType,
        positioning: Bool = false,
        initialPosition: Double? = nil,
        profExplain: Bool = false
    ) -> String {
        let normalized = normalizedPosition(initialPosition)
        let safeInitial = normalized ?? 0
        let initialScript = normalized == nil ? "null" : String(safeInitial)
        let markerVisible = positioning || normalized != nil
        return imageHead(positioning: positioning, markerVisible: markerVisible)
            + imageBodyOpen(base64: base64, mimeType: mimeType, profExplain: profExplain)
            + imageScript(positioning: positioning, initialScript: initialScript)
            + imageClose()
    }

    // MARK: En-tête et feuille de style

    /// `<head>` du document photo, `<style>` compris.
    private static func imageHead(positioning: Bool, markerVisible: Bool) -> String {
        """
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

        """
    }

    // MARK: Corps et image

    /// Ouverture de `<body>` : état d'attente, image en base64, repère de
    /// progression, pont du prof IA (photo) et ouverture du `<script>`.
    private static func imageBodyOpen(base64: String, mimeType: CtdMimeType, profExplain: Bool) -> String {
        let profBridge = profExplain ? "<script>\(profExplainImageScript())</script>" : ""
        return """
          <body>
            <div id="status">Préparation du cours…</div>
            <img id="course-image" alt="Photo du cours" src="data:\(mimeType.rawValue);base64,\(base64)" />
            <div id="class-progress-marker" aria-hidden="true"></div>
            \(profBridge)
            <script>

        """
    }

    // MARK: Script du document

    /// Script embarqué du document photo : pont de messages, suivi de position
    /// et affichage de l'image.
    ///
    /// L'enveloppe `(function () { … })();` est concaténée hors du littéral
    /// multi-lignes : ses accolades n'entrent alors pas dans la mesure de
    /// complexité, qui lit le corps du fichier ligne à ligne.
    private static func imageScript(positioning: Bool, initialScript: String) -> String {
        "      (function () {\n"
            + imageScriptSetup(positioning: positioning, initialScript: initialScript)
            + imageScriptEvents()
            + "      })();\n"
    }

    /// Déclarations du script et pilotage du repère (`notify`,
    /// `currentPosition`, `applyPositioning`).
    private static func imageScriptSetup(positioning: Bool, initialScript: String) -> String {
        """
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

        """
    }

    /// Écouteurs et affichage (`message`, `scroll`, `load`, `error`).
    private static func imageScriptEvents() -> String {
        """
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
                  // Bouton « Expliquer cette photo » du pont du prof IA : posé
                  // seulement quand le pont a été injecté (`profExplain`).
                  if (window.__duelloProfImage) {
                    window.__duelloProfImage.photoButton(image);
                  }
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
                  notify('error', { message: 'image' });
                });

        """
    }

    /// Fermeture du document.
    private static func imageClose() -> String {
        """
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
