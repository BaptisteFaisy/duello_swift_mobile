//
//  PyConSandbox.swift
//  Duello
//
//  Bac à sable Python réel de la console d'informatique, porté de l'app Expo.
//
//  Sources portées : `PythonSandboxView.native.tsx` (WebView hors écran 1×1,
//  opacité 0, `pointerEvents:none` — elle n'existe que pour exécuter le
//  programme de l'élève à l'écart de l'application : ni compte, ni données, ni
//  relais de correction) et `utils/pythonConsole.ts` (document isolé
//  `pythonSandboxHtml`, interpréteur `PYTHON_RUNTIME_SOURCE`, protocole
//  `parsePythonSandboxMessage`, ordre `pythonRunOrder`).
//
//  Le document charge Pyodide (CPython en WebAssembly) depuis le CDN
//  `PYODIDE_INDEX_URL` et se dit servi par ce CDN (`PYTHON_SANDBOX_BASE_URL`) :
//  sans cette origine empruntée, le téléchargement serait refusé. Le pont iOS
//  reprend le contrat Expo — le document appelle
//  `window.ReactNativeWebView.postMessage`, redirigé vers le canal
//  `WKScriptMessageHandler` `duelloConsole` ; les ordres partent par
//  `evaluateJavaScript` (`window.duelloRecevoir`).
//
//  V1 (2026-09-29) — écart P0 « Python réel » d'IMPL-12 : le raccord manquant
//  est comblé dans un fichier dédié. L'exécution simulée de `PythonConsoleView`
//  peut céder la place à ce bac à sable ; la console hôte
//  (`PythonConsoleView.swift`, lot IMPL-12) reste à raccorder.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation
import SwiftUI
import WebKit

// MARK: - Bornes

/// Bornes nommées du bac à sable (`pythonConsole.ts`). Aucune de ces valeurs ne
/// doit apparaître en dur dans le corps des fonctions ou des vues.
enum PyConSandboxConstants {
    /// Distribution Pyodide chargée (`PYODIDE_VERSION`, CPython 3.14, WASM).
    static let pyodideVersion = "v314.0.3"
    /// Racine des fichiers Pyodide (`PYODIDE_INDEX_URL`).
    static let indexURL = "https://cdn.jsdelivr.net/pyodide/\(pyodideVersion)/full/"
    /// Origine prêtée au document (`PYTHON_SANDBOX_BASE_URL`).
    static let baseURL = indexURL
    /// Message transporté par l'`iframe` web (`PYTHON_SANDBOX_MESSAGE_TYPE`).
    static let messageType = "duello-python-console"
    /// Téléchargement (~10 Mo) + démarrage (`PYTHON_BOOT_TIMEOUT_MS`).
    static let bootTimeoutMs = 120_000
    /// Repli quand le document signale une panne sans texte exploitable.
    static let startupFailureFallback = "La console Python n’a pas pu démarrer."
}

// MARK: - Interpréteur embarqué

/// Interpréteur installé dans Pyodide (`PYTHON_RUNTIME_SOURCE`) : il isole une
/// sortie capturée, une trace limitée au programme de l'élève et un compteur qui
/// interrompt une boucle sans fin. Repris mot pour mot de la source Expo.
private let pyConRuntimeSource = #"""
import ast, io, json, linecache, sys, time, traceback

_FICHIER = "programme.py"
_SORTIE_MAX = 20000
# Relever l'horloge à chaque ligne coûterait plus cher que le programme
# lui-même : un contrôle tous les deux mille pas suffit à borner l'attente.
_PAS_ENTRE_CONTROLES = 2000


class _Depassement(BaseException):
    """Hors de la hiérarchie d'Exception : un except du programme de l'élève ne
    doit pas pouvoir rattraper l'interruption qui le sort d'une boucle sans fin."""


class _Sortie(io.StringIO):
    def __init__(self):
        super().__init__()
        self.ecrit = 0
        self.coupee = False

    def write(self, texte):
        if self.ecrit >= _SORTIE_MAX:
            self.coupee = True
            return len(texte)
        place = _SORTIE_MAX - self.ecrit
        self.ecrit += len(texte)
        if len(texte) > place:
            self.coupee = True
            return super().write(texte[:place])
        return super().write(texte)


def _pas_de_saisie(invite=""):
    raise RuntimeError(
        "input() n'est pas disponible dans la console : écris directement "
        "dans ton programme les valeurs à tester."
    )


def _sentinelle(echeance):
    reste = [_PAS_ENTRE_CONTROLES]

    def trace(frame, evenement, argument):
        reste[0] -= 1
        if reste[0] <= 0:
            reste[0] = _PAS_ENTRE_CONTROLES
            if time.monotonic() > echeance:
                raise _Depassement()
        return trace

    return trace


def _compiler(code):
    # Sans cette ligne, la trace afficherait les numéros de ligne sans le texte
    # correspondant : l'élève ne verrait pas laquelle a échoué.
    linecache.cache[_FICHIER] = (len(code), None, code.splitlines(True), _FICHIER)
    arbre = ast.parse(code, _FICHIER, "exec")
    # Dernière ligne réduite à une expression : la console l'affiche, comme le
    # ferait un interpréteur interactif.
    if arbre.body and isinstance(arbre.body[-1], ast.Expr):
        fin = ast.Expression(arbre.body.pop().value)
        return compile(arbre, _FICHIER, "exec"), compile(fin, _FICHIER, "eval")
    return compile(arbre, _FICHIER, "exec"), None


def _trace_eleve(genre, valeur, trace):
    cadres = [
        cadre
        for cadre in traceback.extract_tb(trace)
        if cadre.filename == _FICHIER
    ]
    lignes = ["Traceback (most recent call last):"] if cadres else []
    lignes += [ligne.rstrip("\n") for ligne in traceback.format_list(cadres)]
    lignes += [
        ligne.rstrip("\n")
        for ligne in traceback.format_exception_only(genre, valeur)
    ]
    return "\n".join(lignes).strip()


def duello_executer(code, limite):
    sortie = _Sortie()
    flux = sys.stdout, sys.stderr
    etat, erreur = "ok", ""
    espace = {"__name__": "__main__", "input": _pas_de_saisie}
    sys.stdout = sys.stderr = sortie
    try:
        try:
            corps, fin = _compiler(code)
        except SyntaxError:
            etat = "error"
            erreur = "".join(
                traceback.format_exception_only(*sys.exc_info()[:2])
            ).strip()
            corps = fin = None
        if corps is not None:
            sys.settrace(_sentinelle(time.monotonic() + limite))
            try:
                exec(corps, espace)
                if fin is not None:
                    valeur = eval(fin, espace)
                    if valeur is not None:
                        print(repr(valeur))
            except _Depassement:
                etat = "timeout"
                erreur = (
                    "Ton programme tourne encore après %g secondes : "
                    "il boucle sans doute sans fin." % limite
                )
            except SystemExit:
                pass
            except BaseException:
                etat = "error"
                erreur = _trace_eleve(*sys.exc_info())
            finally:
                sys.settrace(None)
    finally:
        sys.stdout, sys.stderr = flux
    return json.dumps(
        {
            "status": etat,
            "output": sortie.getvalue(),
            "error": erreur,
            "truncated": sortie.coupee,
        }
    )
"""#

// MARK: - Document isolé

/// Document chargé par la WebView (`pythonSandboxHtml`), gabarit à jetons :
/// `PyConSandbox.html()` y injecte l'URL Pyodide, l'interpréteur, la limite et
/// le nom du canal. Les jetons `@@…@@` ne peuvent apparaître ni dans une URL ni
/// dans un littéral JSON, donc aucune collision.
private let pyConSandboxTemplate = #"""
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<style>html,body{margin:0;padding:0;background:transparent;}</style>
</head>
<body>
<script>
// Pont iOS : le contrat Expo appelle `window.ReactNativeWebView`.
window.ReactNativeWebView = {
  postMessage: function (payload) {
    window.webkit.messageHandlers.@@BRIDGE@@.postMessage(payload);
  }
};
</script>
<script>
(function () {
  var INDEX_URL = @@INDEX_URL@@;
  var RUNTIME = @@RUNTIME@@;
  var LIMITE = @@LIMITE@@;
  var MESSAGE_TYPE = @@MESSAGE_TYPE@@;
  var python = null;
  var demarrage = null;

  function envoyer(message) {
    var brut = JSON.stringify(message);
    if (window.ReactNativeWebView) {
      window.ReactNativeWebView.postMessage(brut);
      return;
    }
    window.parent.postMessage({ type: MESSAGE_TYPE, data: brut }, '*');
  }

  function texte(erreur) {
    if (!erreur) return 'cause inconnue';
    return String(erreur.message || erreur);
  }

  function charger(src) {
    return new Promise(function (resoudre, rejeter) {
      var balise = document.createElement('script');
      balise.src = src;
      balise.onload = function () { resoudre(); };
      balise.onerror = function () {
        rejeter(new Error('téléchargement impossible'));
      };
      document.head.appendChild(balise);
    });
  }

  function demarrer() {
    if (demarrage) return demarrage;
    demarrage = charger(INDEX_URL + 'pyodide.js')
      .then(function () { return loadPyodide({ indexURL: INDEX_URL }); })
      .then(function (instance) {
        python = instance;
        python.runPython(RUNTIME);
        envoyer({ type: 'ready' });
        return instance;
      });
    // Une panne de démarrage n'est pas définitive : le prochain appui doit
    // pouvoir retenter le téléchargement.
    demarrage.catch(function () { demarrage = null; });
    return demarrage;
  }

  function executer(id, code) {
    envoyer({ type: 'running', id: id });
    demarrer()
      .then(function () {
        // Un import de numpy ou de matplotlib va chercher le paquet ; un code
        // qui ne compile pas ressort d'ici sans rien avoir chargé.
        return python.loadPackagesFromImports(code).catch(function () {});
      })
      .then(function () {
        python.globals.set('_duello_code', code);
        var brut = python.runPython('duello_executer(_duello_code, ' + LIMITE + ')');
        envoyer({ type: 'result', id: id, result: JSON.parse(brut) });
      })
      .catch(function (erreur) {
        envoyer({ type: 'failed', id: id, message: texte(erreur) });
      });
  }

  function recevoir(brut) {
    var message;
    try { message = JSON.parse(brut); } catch (erreur) { return; }
    if (!message || message.type !== 'run') return;
    if (typeof message.id !== 'string' || typeof message.code !== 'string') return;
    executer(message.id, message.code);
  }

  window.duelloRecevoir = recevoir;
  window.addEventListener('message', function (evenement) {
    if (typeof evenement.data === 'string') recevoir(evenement.data);
  });
  window.addEventListener('error', function (evenement) {
    envoyer({ type: 'failed', message: texte(evenement.error || evenement.message) });
  });

  envoyer({ type: 'loaded' });
})();
</script>
</body>
</html>
"""#

// MARK: - Protocole

/// Document isolé et protocole d'échange (`pythonConsole.ts`).
enum PyConSandbox {
    /// `pythonSandboxHtml` : le document chargé par la WebView. Il ne contient
    /// aucune donnée du compte — il reçoit du code, renvoie une sortie, et rien
    /// d'autre ne le traverse.
    static func html() -> String {
        let values: [(String, String)] = [
            ("@@INDEX_URL@@", jsonLiteral(PyConSandboxConstants.indexURL)),
            ("@@RUNTIME@@", jsonLiteral(pyConRuntimeSource)),
            ("@@LIMITE@@", String(PyConLimits.timeLimitSeconds)),
            ("@@MESSAGE_TYPE@@", jsonLiteral(PyConSandboxConstants.messageType)),
            ("@@BRIDGE@@", PyConSandboxView.bridgeName),
        ]
        return values.reduce(pyConSandboxTemplate) { text, pair in
            text.replacingOccurrences(of: pair.0, with: pair.1)
        }
    }

    /// `pythonRunOrder` : ordre d'exécution envoyé au document isolé, déjà
    /// sérialisé.
    static func runOrder(id: String, code: String) -> String {
        let order: [String: String] = ["type": "run", "id": id, "code": code]
        guard let data = try? JSONSerialization.data(withJSONObject: order),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    /// Rend une chaîne Swift en littéral JSON, sûr à insérer dans du
    /// JavaScript (`JSON.stringify` de la source).
    static func jsonLiteral(_ text: String) -> String {
        guard let data = try? JSONSerialization.data(
                withJSONObject: text, options: [.withoutEscapingSlashes]),
              let literal = String(data: data, encoding: .utf8) else { return "\"\"" }
        return literal
    }
}

// MARK: - Protocole de messages

/// Message émis par le document isolé (`PythonSandboxMessage`).
enum PyConSandboxMessage {
    case loaded
    case ready
    case running(id: String)
    case result(id: String, result: PyConRunResult)
    case failed(id: String?, message: String)

    /// `parsePythonSandboxMessage` : tout ce qui n'est pas reconnu est ignoré —
    /// la console partage la fenêtre avec d'autres émetteurs.
    init?(raw: String) {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let message = object as? [String: Any],
              let type = message["type"] as? String
        else { return nil }

        switch type {
        case "loaded", "ready":
            self = (type == "loaded") ? .loaded : .ready
        case "running":
            guard let id = message["id"] as? String else { return nil }
            self = .running(id: id)
        case "failed":
            let text = (message["message"] as? String)?
                .trimmingCharacters(in: .whitespaces) ?? ""
            self = .failed(
                id: message["id"] as? String,
                message: text.isEmpty ? PyConSandboxConstants.startupFailureFallback : text
            )
        case "result":
            guard let id = message["id"] as? String,
                  let payload = message["result"] as? [String: Any],
                  let result = PyConRunResult(payload: payload)
            else { return nil }
            self = .result(id: id, result: result)
        default:
            return nil
        }
    }
}

extension PyConRunResult {
    /// Résultat lu d'un message `result` du document
    /// (`parsePythonSandboxMessage`). `nil` si le statut n'est pas reconnu.
    init?(payload: [String: Any]) {
        let status: PyConRunStatus
        switch payload["status"] as? String {
        case "ok": status = .ok
        case "error": status = .error
        case "timeout": status = .timeout
        default: return nil
        }
        self.init(
            status: status,
            output: payload["output"] as? String ?? "",
            error: payload["error"] as? String ?? "",
            truncated: (payload["truncated"] as? Bool) == true
        )
    }
}

// MARK: - Poignée de commande

/// Poignée impérative du bac à sable (`PythonSandboxHandle`) : transmet un ordre
/// déjà sérialisé au document, par `evaluateJavaScript`.
final class PyConSandboxHandle {
    /// WebView du document, posée au montage (`makeUIView`).
    fileprivate weak var webView: WKWebView?

    /// `send` : l'`injectJavaScript` de la source, porté par
    /// `WKWebView.evaluateJavaScript`.
    func send(_ payload: String) {
        guard let webView = webView else { return }
        let call = PyConSandbox.jsonLiteral(payload)
        let script = "window.duelloRecevoir && window.duelloRecevoir(\(call)); true;"
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
}

// MARK: - Vue

/// WebView hors écran (`PythonSandboxView.native.tsx`) : montée une fois et
/// jamais démontée entre deux exécutions — une WebView démontée rechargerait les
/// dix mégaoctets de l'interpréteur à chaque appui.
struct PyConSandboxView: UIViewRepresentable {
    /// Nom du canal `WKScriptMessageHandler` du document.
    static let bridgeName = "duelloConsole"

    /// Poignée qui reçoit la WebView montée.
    let handle: PyConSandboxHandle
    /// Messages du document, en JSON, comme `onMessage` côté Expo.
    var onMessage: ((String) -> Void)? = nil

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: Self.bridgeName)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.loadHTMLString(
            PyConSandbox.html(),
            baseURL: URL(string: PyConSandboxConstants.baseURL)
        )
        context.coordinator.handle = handle
        handle.webView = webView
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
        webView.configuration.userContentController
            .removeScriptMessageHandler(forName: bridgeName)
        coordinator.handle?.webView = nil
    }

    /// Reçoit les messages du document et les rend à la console.
    final class Coordinator: NSObject, WKScriptMessageHandler {
        var onMessage: ((String) -> Void)?
        weak var handle: PyConSandboxHandle?

        init(onMessage: ((String) -> Void)?) {
            self.onMessage = onMessage
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == PyConSandboxView.bridgeName,
                  let text = message.body as? String else { return }
            onMessage?(text)
        }
    }
}

/// Hôte hors flux du bac à sable (`styles.host` de la source Expo) : surface
/// 1×1, transparente et non interactive, mais bien montée.
struct PyConSandboxHost: View {
    let handle: PyConSandboxHandle
    var onMessage: ((String) -> Void)? = nil

    var body: some View {
        PyConSandboxView(handle: handle, onMessage: onMessage)
            .frame(width: 1, height: 1)
            .opacity(0)
            .allowsHitTesting(false)
    }
}
