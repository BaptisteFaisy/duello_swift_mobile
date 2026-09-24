//
//  ProfDocBridge.swift
//  Duello
//
//  Port de `src/utils/profSelectionBridge.ts` et `src/utils/profTextLayer.ts`
//  (RN) — pont « sélectionner sans copier » injecté dans les documents lus en
//  WebView (cours PDF, page d'annale, corrigé composé), et calque de sélection
//  posé sur chaque page PDF rendue en canvas.
//
//  Le script affiche un bouton « Expliquer ce passage » sur toute sélection,
//  publie le passage vers l'app et bloque copie, coupe et menu contextuel. Le
//  JavaScript reste volontairement simple (pas de modules ni de gabarits) pour
//  tourner tel quel dans les WebView iOS comme dans les iframes web. Il publie
//  via `window.ReactNativeWebView.postMessage`, que `CtdHtmlDocumentView` redirige
//  déjà vers le canal `duello` — les deux moitiés du pont se répondent sans
//  modification de l'hôte.
//
//  Le calque de texte rend chaque mot sélectionnable sans repeindre la page :
//  les `<span>` transparents se posent sur le texte rasterisé. Une page sans mot
//  publie `duello-prof-no-text` (scan ou image) pour que l'app l'explique.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

// MARK: - Événements du pont

/// `ProfBridgeEvent` : message lu du pont WebView.
enum ProfBridgeEvent: Equatable {
    case explain(text: String, page: Int?)
    case copyBlocked
    case noText(page: Int?)
}

// MARK: - Calque de texte

/// `PROF_TEXT_LAYER_CLASS` : classe des calques posés sur les pages PDF.
let PROF_TEXT_LAYER_CLASS = "duello-prof-layer"

/// `profTextLayerCss` : styles du calque (texte transparent, sélection active).
func profTextLayerCss() -> String {
    profTextLayerStylesheet
}

/// `profTextLayerScript` : construit le calque d'une page après son rendu canvas.
func profTextLayerScript() -> String {
    profTextLayerJavascript
}

private let profTextLayerStylesheet = """
.\(PROF_TEXT_LAYER_CLASS){position:absolute;left:0;top:0;overflow:hidden;pointer-events:none;}
.\(PROF_TEXT_LAYER_CLASS) span{position:absolute;pointer-events:auto;color:transparent;user-select:text;-webkit-user-select:text;cursor:text;white-space:pre;transform-origin:0 0;}
.\(PROF_TEXT_LAYER_CLASS) span::selection{background:rgba(22,163,74,.25);}
"""

// MARK: - Pont de sélection

/// `profSelectionBridgeScript` : script du bouton « Expliquer ce passage ».
func profSelectionBridgeScript() -> String {
    profSelectionBridgeJavascript
}

// MARK: - Lecture des messages

/// `parseProfBridgeMessage` : lit un message du pont sans jamais lever ;
/// l'étranger est ignoré, le passage est rogné au plafond anti-abus.
func parseProfBridgeMessage(_ raw: String) -> ProfBridgeEvent? {
    guard let data = raw.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data),
          let dictionary = object as? [String: Any],
          let type = dictionary["type"] as? String
    else { return nil }

    if type == "duello-prof-copy-blocked" { return .copyBlocked }
    let page = profBridgePage(dictionary["page"])
    if type == "duello-prof-no-text" { return .noText(page: page) }
    guard type == "duello-prof-explain", let text = dictionary["text"] as? String else {
        return nil
    }
    let clamped = clampProfQuote(text)
    guard !clamped.isEmpty else { return nil }
    return .explain(text: clamped, page: page)
}

/// `Math.max(1, Math.floor(page))` : numéro de page entier, au moins 1.
private func profBridgePage(_ raw: Any?) -> Int? {
    guard let number = raw as? Double, number.isFinite else { return nil }
    return max(1, Int(number.rounded(.down)))
}

// MARK: - Scripts injectés (verbatim de la source)

/// `profSelectionBridgeScript` de `profSelectionBridge.ts`, repris mot pour mot.
private let profSelectionBridgeJavascript = """
(function(){
  if (window.__duelloProfBridge) return;
  window.__duelloProfBridge = true;
  function notify(payload) {
    if (window.ReactNativeWebView) {
      window.ReactNativeWebView.postMessage(JSON.stringify(payload));
    }
  }
  var btn = document.createElement('button');
  btn.innerHTML = '<span style="display:inline-block;width:7px;height:7px;'
    + 'border-radius:999px;background:#22C55E;margin-right:7px;"></span>Expliquer ce passage';
  btn.style.cssText = 'display:none;position:absolute;z-index:50;align-items:center;'
    + 'background:#0A0D0C;color:#fff;border:none;font:700 13px system-ui,sans-serif;'
    + 'padding:9px 15px;border-radius:999px;box-shadow:0 8px 22px rgba(10,13,12,.35);'
    + 'cursor:pointer;white-space:nowrap;';
  document.body.appendChild(btn);
  var toast = document.createElement('div');
  toast.textContent = 'Sélection réservée au prof IA : la copie est désactivée';
  toast.style.cssText = 'position:fixed;left:50%;bottom:24px;transform:translateX(-50%);'
    + 'z-index:60;max-width:92%;background:#0A0D0C;color:#fff;font:600 13px system-ui,sans-serif;'
    + 'padding:10px 18px;border-radius:999px;opacity:0;transition:opacity .25s;'
    + 'pointer-events:none;text-align:center;';
  document.body.appendChild(toast);
  var toastTimer = 0;
  function showToast() {
    toast.style.opacity = '1';
    if (toastTimer) clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { toast.style.opacity = '0'; }, 2200);
  }
  function currentText() {
    var sel = window.getSelection();
    if (!sel || sel.isCollapsed) return '';
    return String(sel.toString()).trim();
  }
  function placeButton() {
    if (!currentText()) {
      btn.style.display = 'none';
      return;
    }
    var sel = window.getSelection();
    var range = sel && sel.rangeCount ? sel.getRangeAt(0) : null;
    if (!range) {
      btn.style.display = 'none';
      return;
    }
    var rect = range.getBoundingClientRect();
    if (!rect || rect.width < 4) {
      btn.style.display = 'none';
      return;
    }
    btn.style.display = 'flex';
    btn.style.left = Math.max(8, rect.left + window.scrollX) + 'px';
    btn.style.top = Math.max(8, rect.top + window.scrollY - 48) + 'px';
  }
  document.addEventListener('selectionchange', placeButton);
  document.addEventListener('mouseup', function () { setTimeout(placeButton, 30); });
  document.addEventListener('touchend', function () { setTimeout(placeButton, 60); });
  document.addEventListener('scroll', function () { btn.style.display = 'none'; }, true);
  btn.addEventListener('click', function () {
    var text = currentText().slice(0, 4000);
    if (!text) {
      btn.style.display = 'none';
      return;
    }
    var sel = window.getSelection();
    var node = sel ? sel.anchorNode : null;
    var el = node ? (node.nodeType === 1 ? node : node.parentElement) : null;
    var pageEl = el && el.closest ? el.closest('[data-prof-page]') : null;
    var page = pageEl ? Number(pageEl.getAttribute('data-prof-page')) : NaN;
    notify({
      type: 'duello-prof-explain',
      text: text,
      page: isFinite(page) ? page : undefined,
    });
    btn.style.display = 'none';
  });
  function blockCopy(event) {
    event.preventDefault();
    showToast();
    notify({ type: 'duello-prof-copy-blocked' });
  }
  document.addEventListener('copy', blockCopy);
  document.addEventListener('cut', blockCopy);
  document.addEventListener('contextmenu', function (event) { event.preventDefault(); });
})();
"""

/// `profTextLayerScript` de `profTextLayer.ts`, repris mot pour mot.
private let profTextLayerJavascript = """
(function(){
  if (window.__duelloProfTextLayer) return;
  window.__duelloProfTextLayer = function (page, viewport, cssWidth, layer, topOffsetPx) {
    var offset = topOffsetPx || 0;
    return page.getTextContent().then(function (textContent) {
      var items = (textContent.items || []).filter(function (item) {
        return item && typeof item.str === 'string' && item.str.length > 0;
      });
      if (items.length === 0) {
        if (window.ReactNativeWebView) {
          var pageAttr = layer.parentElement
            ? layer.parentElement.getAttribute('data-prof-page')
            : null;
          window.ReactNativeWebView.postMessage(JSON.stringify({
            type: 'duello-prof-no-text',
            page: pageAttr ? Number(pageAttr) : undefined,
          }));
        }
        return;
      }
      var scale = cssWidth / viewport.width;
      var cssHeight = layer.getBoundingClientRect().height
        || (viewport.height * scale - offset * scale);
      items.forEach(function (item) {
        var tx = pdfjsLib.Util.transform(viewport.transform, item.transform);
        var fontHeight = Math.sqrt(tx[2] * tx[2] + tx[3] * tx[3]) * scale;
        if (!isFinite(fontHeight) || fontHeight <= 0) return;
        var top = (tx[5] - offset) * scale - fontHeight;
        if (top < -fontHeight || top > cssHeight) return;
        var span = document.createElement('span');
        span.textContent = item.str;
        span.style.left = (tx[4] * scale) + 'px';
        span.style.top = top + 'px';
        span.style.fontSize = fontHeight + 'px';
        span.style.lineHeight = '1';
        layer.appendChild(span);
      });
    });
  };
})();
"""
