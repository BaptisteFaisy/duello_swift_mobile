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
//  publie `duello-prof-no-text` (scan ou image) pour que l'app l'explique, et
//  pose le bouton « Expliquer » du relais vision (`profExplainImageScript`), qui
//  publie l'image réduite en data-URL (`duello-prof-explain-image`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

// MARK: - Événements du pont

/// `ProfBridgeEvent` : message lu du pont WebView.
enum ProfBridgeEvent: Equatable {
    case explain(text: String, page: Int?)
    case explainImage(image: String, page: Int?)
    case copyBlocked
    case noText(page: Int?)
    /// `text-layer` : mots exposés par le document et mots effectivement
    /// sélectionnables. `items > 0` avec `spans == 0` est la signature d'un
    /// cours que le prof IA ne peut pas lire (`profSelectionBridge.ts:9,129-137`).
    case textLayer(page: Int?, items: Int, spans: Int, error: String?)
}

// MARK: - Calque de texte

/// `PROF_TEXT_LAYER_CLASS` : classe des calques posés sur les pages PDF.
let PROF_TEXT_LAYER_CLASS = "duello-prof-layer"

/// `PROF_TEXT_LAYER_REPORT_TYPE` : type du rapport publié par le calque de
/// texte (`profTextLayer.ts:13`).
let PROF_TEXT_LAYER_REPORT_TYPE = "duello-prof-text-layer"

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

/// `profExplainImageScript` : bouton « Expliquer » des contenus sans texte
/// sélectionnable — photo de cours entière, ou page PDF scannée (appelée par le
/// calque quand la page ne porte aucun mot).
func profExplainImageScript() -> String {
    profExplainImageJavascript
}

/// `PROF_IMAGE_DATA_URL` : data-URLs acceptées (les quatre mimes lus par la
/// vision du relais).
private let profImageDataUrlPattern = "^data:(image/(?:jpeg|png|gif|webp));base64,([A-Za-z0-9+/=\\s]+)$"

/// `parseProfImageDataUrl` : valide l'image publiée par le pont — data-URL
/// d'image, base64 non vide. Le relais retronque les tailles ; ici seul le
/// format est exigé.
func parseProfImageDataUrl(_ dataUrl: String) -> (mimeType: String, base64: String)? {
    let trimmed = dataUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let regex = try? NSRegularExpression(pattern: profImageDataUrlPattern),
          let match = regex.firstMatch(
              in: trimmed,
              range: NSRange(trimmed.startIndex..., in: trimmed)
          ),
          match.numberOfRanges == 3,
          let mimeRange = Range(match.range(at: 1), in: trimmed),
          let base64Range = Range(match.range(at: 2), in: trimmed)
    else { return nil }
    let base64 = String(trimmed[base64Range])
        .filter { !$0.isWhitespace }
    guard !base64.isEmpty else { return nil }
    return (mimeType: String(trimmed[mimeRange]), base64: base64)
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
    if type == PROF_TEXT_LAYER_REPORT_TYPE {
        return .textLayer(
            page: page,
            items: profBridgeCount(dictionary["items"]),
            spans: profBridgeCount(dictionary["spans"]),
            error: dictionary["error"] as? String
        )
    }
    if type == "duello-prof-explain-image" {
        guard let image = dictionary["image"] as? String, !image.isEmpty else { return nil }
        return .explainImage(image: image, page: page)
    }
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

/// `typeof x === 'number' && Number.isFinite(x) ? x : 0` : compte du calque de
/// texte, ramené à 0 quand il n'est pas un nombre fini.
private func profBridgeCount(_ raw: Any?) -> Int {
    guard let number = raw as? Double, number.isFinite else { return 0 }
    return Int(number)
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

/// `profExplainImageScript` de `profSelectionBridge.ts`, repris mot pour mot.
private let profExplainImageJavascript = """
(function(){
  if (window.__duelloProfImage) return;
  var api = {};
  window.__duelloProfImage = api;
  function notify(payload) {
    if (window.ReactNativeWebView) {
      window.ReactNativeWebView.postMessage(JSON.stringify(payload));
    }
  }
  function styleButton(btn) {
    btn.style.cssText = 'display:flex;align-items:center;z-index:50;'
      + 'background:#0A0D0C;color:#fff;border:none;font:700 13px system-ui,sans-serif;'
      + 'padding:9px 15px;border-radius:999px;box-shadow:0 8px 22px rgba(10,13,12,.35);'
      + 'cursor:pointer;white-space:nowrap;';
  }
  function labelButton(btn, label) {
    btn.innerHTML = '<span style="display:inline-block;width:7px;height:7px;'
      + 'border-radius:999px;background:#22C55E;margin-right:7px;"></span>' + label;
  }
  api.downscaleToDataUrl = function (source, maxDim) {
    try {
      var w = source.naturalWidth || source.width;
      var h = source.naturalHeight || source.height;
      if (!w || !h) return null;
      var scale = Math.min(1, (maxDim || 2048) / Math.max(w, h));
      var canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.round(w * scale));
      canvas.height = Math.max(1, Math.round(h * scale));
      var ctx = canvas.getContext('2d');
      if (!ctx) return null;
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(source, 0, 0, canvas.width, canvas.height);
      return canvas.toDataURL('image/jpeg', 0.85);
    } catch (e) {
      return null;
    }
  };
  api.photoButton = function (img) {
    if (!img || document.getElementById('duello-prof-photo-btn')) return;
    var btn = document.createElement('button');
    labelButton(btn, 'Expliquer cette photo');
    styleButton(btn);
    btn.id = 'duello-prof-photo-btn';
    btn.style.position = 'fixed';
    btn.style.left = '50%';
    btn.style.bottom = '18px';
    btn.style.transform = 'translateX(-50%)';
    btn.addEventListener('click', function () {
      var dataUrl = api.downscaleToDataUrl(img, 2048);
      if (!dataUrl) return;
      notify({ type: 'duello-prof-explain-image', image: dataUrl });
    });
    document.body.appendChild(btn);
  };
  api.pageButton = function (holder, pageNumber) {
    if (!holder || holder.querySelector('.duello-prof-page-btn')) return;
    var btn = document.createElement('button');
    labelButton(btn, 'Expliquer');
    styleButton(btn);
    btn.className = 'duello-prof-page-btn';
    btn.style.position = 'absolute';
    btn.style.top = '10px';
    btn.style.right = '10px';
    btn.addEventListener('click', function () {
      var canvas = holder.querySelector('canvas');
      if (!canvas) return;
      var dataUrl = api.downscaleToDataUrl(canvas, 2048);
      if (!dataUrl) return;
      notify({ type: 'duello-prof-explain-image', image: dataUrl, page: pageNumber });
    });
    holder.appendChild(btn);
  };
})();
"""

/// `profTextLayerScript` de `profTextLayer.ts`, repris mot pour mot.
private let profTextLayerJavascript = """
(function(){
  if (window.__duelloProfTextLayer) return;
  var report = function (page, items, spans, error) {
    if (!window.ReactNativeWebView) return;
    var payload = { type: '\(PROF_TEXT_LAYER_REPORT_TYPE)', items: items, spans: spans };
    if (page) payload.page = page;
    if (error) payload.error = error;
    window.ReactNativeWebView.postMessage(JSON.stringify(payload));
  };
  window.__duelloProfTextLayer = function (page, viewport, cssWidth, layer, topOffsetPx) {
    var offset = topOffsetPx || 0;
    var pageAttr = layer.parentElement
      ? layer.parentElement.getAttribute('data-prof-page')
      : null;
    var pageNumber = pageAttr ? Number(pageAttr) : undefined;
    return page.getTextContent().then(function (textContent) {
      var items = (textContent.items || []).filter(function (item) {
        return item && typeof item.str === 'string' && item.str.length > 0;
      });
      if (items.length === 0) {
        if (window.ReactNativeWebView) {
          window.ReactNativeWebView.postMessage(JSON.stringify({
            type: 'duello-prof-no-text',
            page: pageNumber,
          }));
        }
        if (window.__duelloProfImage && layer.parentElement) {
          window.__duelloProfImage.pageButton(layer.parentElement, pageNumber);
        }
        report(pageNumber, 0, 0);
        return;
      }
      var scale = cssWidth / viewport.width;
      var cssHeight = layer.getBoundingClientRect().height
        || (viewport.height * scale - offset * scale);
      var spans = 0;
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
        spans += 1;
      });
      report(pageNumber, items.length, spans);
    });
  };
})();
"""
