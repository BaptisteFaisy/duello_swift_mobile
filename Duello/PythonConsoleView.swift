//
//  PythonConsoleView.swift
//  Duello
//
//  Console Python sous le champ de réponse, portée depuis l'application
//  Expo / React Native « Duello ».
//
//  Fichiers source portés :
//  - `expo_ref/src/components/PythonConsole.tsx` — barre d'exécution (bouton
//    « Exécuter », libellés de phase, phrase d'aide) et panneau de sortie
//    (fond `colors.ink`, texte `Menlo` 12, erreur `#FF9A9E`, note
//    `colors.inkFaint`, hauteur max 190, marges 9, rayon 9) ;
//  - `expo_ref/src/utils/pythonConsole.ts` — bornes (`PYTHON_TIME_LIMIT_SECONDS`,
//    `PYTHON_BOOT_TIMEOUT_MS`, `PYTHON_RUN_TIMEOUT_MS`, sortie max 20 000),
//    statuts, rapport et messages de démarrage ;
//  - `expo_ref/src/components/PythonSandboxView.native.tsx` — WebView Pyodide
//    hors écran, portée par `PyConSandbox.swift`.
//
//  V2 (2026-09-29) — raccord du bac à sable réel (P0 18#1) : `PyConRunner`, qui
//  simulait les `print(…)` littéraux, est remplacé par le bac à sable Pyodide de
//  `PyConSandbox.swift`. La console monte `PyConSandboxHost`, garde le
//  `PyConSandboxHandle`, envoie un ordre `run` par exécution et route chaque
//  `PyConSandboxMessage` (`loaded`/`ready`/`running`/`result`/`failed`) vers son
//  état — comme le `handleMessage` de la source Expo. Plus rien n'est simulé :
//  le programme de l'élève tourne réellement, sur l'appareil.
//
//  Écart restant — **P1 `firstBlockingQuestion` non appelé.** Le point d'appel de
//  la source (`AnnaleViewer.tsx:3375`, avant la soumission) vit dans le lecteur
//  (`AnnReaderWorkspace.swift`, hors lot) : il instancie encore un modèle sans
//  bac à sable monté. À raccorder (vague 6).
//

import Foundation
import SwiftUI

// MARK: - Statuts et phases

/// Statut d'une exécution, repris de `PythonRunStatus` de la source Expo.
enum PyConRunStatus {
    case ok
    case error
    case timeout
    case unavailable
}

/// Phase d'affichage de la console (`ConsolePhase` de la source Expo).
enum PyConPhase: Equatable {
    case idle
    case starting
    case running
}

// MARK: - Résultat et rapport

/// Résultat d'une exécution (`PythonRunResult` de la source Expo).
struct PyConRunResult {
    let status: PyConRunStatus
    /// Ce que le programme a écrit, `print` et flux d'erreur confondus.
    let output: String
    /// Message de syntaxe, trace ou cause de l'indisponibilité.
    let error: String
    /// Vrai quand la sortie a été coupée parce qu'elle devenait interminable.
    let truncated: Bool

    /// `pythonRunBlocksCorrection` (`utils/pythonConsole.ts:130-132`) : une
    /// correction ne part pas sur un programme qui ne tourne pas. Une console
    /// indisponible ne bloque rien, en revanche — la panne vient de
    /// l'application, pas de la copie.
    var blocksCorrection: Bool {
        status == .error || status == .timeout
    }

    /// Découpe le résultat en trois parties (`pythonConsoleReport`) : sortie
    /// débarrassée de ses espaces finaux, erreur ajustée, note contextuelle.
    var report: PyConReport {
        var cleanOutput = output
        while let last = cleanOutput.last, last.isWhitespace {
            cleanOutput.removeLast()
        }
        let cleanError = error.trimmingCharacters(in: .whitespacesAndNewlines)
        var note = ""
        if truncated {
            note = PyConLimits.truncatedNote
        } else if cleanOutput.isEmpty && cleanError.isEmpty {
            note = PyConLimits.noOutputNote
        }
        return PyConReport(output: cleanOutput, error: cleanError, note: note)
    }
}

/// Sortie découpée pour l'affichage (`PythonConsoleReport` de la source Expo).
struct PyConReport {
    let output: String
    let error: String
    let note: String
}

// MARK: - Bornes et libellés

/// Bornes et libellés nommés : aucune de ces valeurs ne doit apparaître en dur
/// dans le corps des fonctions ou des vues.
enum PyConLimits {
    /// Temps laissé au programme avant d'être déclaré bouclé (`5 s`,
    /// `PYTHON_TIME_LIMIT_SECONDS`), injecté dans le document par
    /// `PyConSandbox.html()`.
    static let timeLimitSeconds = 5
    /// Téléchargement (~10 Mo) + démarrage de l'interpréteur
    /// (`PYTHON_BOOT_TIMEOUT_MS`), pour la première exécution.
    static let bootTimeoutMs = 120_000
    /// Garde-fou applicatif : une exécution figée ne répondrait plus du tout
    /// (`PYTHON_RUN_TIMEOUT_MS`).
    static let runTimeoutMs = 20_000
    /// Hauteur maximale du panneau de sortie (points).
    static let outputMaxHeight: CGFloat = 190

    static let runButtonLabel = "Exécuter"
    static let startingLabel = "Démarrage de Python…"
    static let runningLabel = "Exécution…"
    static let deviceHint = "Ton programme tourne sur ton appareil : rien n’est envoyé."
    static let firstRunHint = "Première exécution : Python se télécharge une fois (environ 10 Mo)."
    static let accessibilityRunLabel = "Exécuter mon programme Python"

    static let emptyProgramMessage = "Écris un programme avant de l’exécuter."
    static let notRespondingMessage = "La console Python ne répond plus. Réessaie dans un instant."
    static let closedMessage = "Console Python fermée avant la fin."
    static let truncatedNote = "Sortie coupée : ton programme affiche trop de lignes."
    static let noOutputNote = "Programme exécuté sans erreur. Il n’affiche rien : ajoute un print(…) pour voir ton résultat."

    /// Couleur de l'erreur dans le panneau sombre (`#FF9A9E`).
    static let errorColor = Color(red: 1.0, green: 0.604, blue: 0.62)

    /// `startupFailureText` de la source : la cause entre parenthèses, suivie du
    /// rappel que l'interpréteur ne se télécharge qu'une fois.
    static func startupFailure(_ cause: String) -> String {
        "Python n’a pas pu démarrer (\(cause)). L’interpréteur se télécharge une seule fois : vérifie ta connexion, puis réessaie."
    }

    /// Résultat servi quand l'exécution n'a pas eu lieu (`unavailablePythonRun`).
    static func unavailable(_ message: String) -> PyConRunResult {
        PyConRunResult(status: .unavailable, output: "", error: message, truncated: false)
    }
}

// MARK: - Modèle de la console

/// État de la console et point d'entrée des exécutions. Reprend le handle
/// impératif `run` de la source Expo : la soumission d'une réponse passe par
/// `run`, qui publie le résultat comme si l'élève avait appuyé sur « Exécuter ».
final class PyConConsoleModel: ObservableObject {
    @Published private(set) var result: PyConRunResult?
    @Published private(set) var phase: PyConPhase = .idle
    @Published private(set) var hasStarted = false
    /// Change quand le document doit être remonté (`generation` de la source) :
    /// un document figé ne répondrait plus, seul son remplacement le débloque.
    @Published private(set) var generation = 0

    /// Poignée du bac à sable : l'hôte y pose sa WebView, `run` s'en sert pour
    /// transmettre l'ordre `run` au document isolé.
    let sandbox = PyConSandboxHandle()

    /// Le document a répondu `loaded` : il peut recevoir des ordres.
    private var loaded = false
    /// L'interpréteur est démarré : les exécutions suivantes sont immédiates.
    private var ready = false
    /// Ordres émis avant que le document ne soit prêt, rejoués à `loaded`.
    private var queued: [String] = []
    /// Exécutions en attente de résultat, par identifiant (`run-1`, `run-2`…).
    private var pending: [String: CheckedContinuation<PyConRunResult, Never>] = [:]
    /// Garde-fous de délai, par identifiant d'exécution.
    private var timers: [String: DispatchWorkItem] = [:]
    private var counter = 0

    init() {}

    deinit {
        // Aucune exécution ne doit rester suspendue à la disparition du modèle.
        for waiting in pending.values {
            waiting.resume(returning: PyConLimits.unavailable(PyConLimits.closedMessage))
        }
    }

    /// Handle `run` de la source Expo : exécute `source` dans le bac à sable et
    /// rend son résultat. Un programme vide est refusé sans rien lancer.
    func run(_ source: String) async -> PyConRunResult {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let value = PyConLimits.unavailable(PyConLimits.emptyProgramMessage)
            result = value
            return value
        }

        hasStarted = true
        result = nil
        phase = ready ? .running : .starting
        counter += 1
        let id = "run-\(counter)"
        let firstStart = !ready

        return await withCheckedContinuation { continuation in
            pending[id] = continuation
            armTimeout(id, firstStart: firstStart)
            let payload = PyConSandbox.runOrder(id: id, code: source)
            if loaded {
                sandbox.send(payload)
            } else {
                queued.append(payload)
            }
        }
    }

    /// `checkPythonBeforeCorrection` (`AnnaleViewer.tsx:3261-3275`) : exécute les
    /// programmes concernés avant d'engager une correction et rend l'identifiant
    /// de la première question qui échoue, `nil` si tout tourne. Les programmes
    /// vides sont ignorés ; une console indisponible ne bloque rien.
    func firstBlockingQuestion(_ sources: [(id: String, source: String)]) async -> String? {
        for entry in sources {
            guard !entry.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            if await run(entry.source).blocksCorrection { return entry.id }
        }
        return nil
    }

    /// Route un message du document isolé (`handleMessage` de la source Expo).
    /// Tout message non reconnu est ignoré : la console partage la fenêtre avec
    /// d'autres émetteurs.
    func handleMessage(_ raw: String) {
        guard let message = PyConSandboxMessage(raw: raw) else { return }
        switch message {
        case .loaded:
            loaded = true
            let waiting = queued
            queued = []
            for payload in waiting { sandbox.send(payload) }
        case .ready:
            ready = true
        case .running:
            phase = .running
        case let .result(id, value):
            settle(id, value)
        case let .failed(id, cause):
            ready = false
            let value = PyConLimits.unavailable(PyConLimits.startupFailure(cause))
            if let id = id {
                settle(id, value)
            } else {
                for key in Array(pending.keys) { settle(key, value) }
            }
        }
    }

    /// Rend le résultat attendu à une exécution et remet la console au repos.
    private func settle(_ id: String, _ value: PyConRunResult) {
        guard let waiting = pending.removeValue(forKey: id) else { return }
        timers.removeValue(forKey: id)?.cancel()
        result = value
        phase = .idle
        waiting.resume(returning: value)
    }

    /// `restart` de la source : remonte le document et rend la main au prochain
    /// appui, qui retentera le téléchargement.
    private func restart() {
        loaded = false
        ready = false
        queued = []
        generation += 1
    }

    /// Garde-fou applicatif : passé le délai (démarrage 120 s, exécution 20 s),
    /// le document est tenu pour figé, remonté, et l'exécution close.
    private func armTimeout(_ id: String, firstStart: Bool) {
        let delay = firstStart ? PyConLimits.bootTimeoutMs : PyConLimits.runTimeoutMs
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.pending[id] != nil else { return }
            self.restart()
            self.settle(id, PyConLimits.unavailable(PyConLimits.notRespondingMessage))
        }
        timers[id] = item
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay), execute: item)
    }
}

// MARK: - Vue

/// Console Python affichée sous le champ de réponse : un bouton « Exécuter », la
/// sortie du programme, ses erreurs et sa trace. Le programme tourne réellement
/// dans le bac à sable Pyodide (`PyConSandbox.swift`), monté hors écran dès la
/// première exécution.
struct PythonConsoleView: View {
    /// Programme actuellement écrit dans le champ de réponse.
    let code: String
    var disabled: Bool = false
    /// Rappel appelé après chaque exécution, comme le handle `run` de la source.
    var onResult: ((PyConRunResult) -> Void)? = nil

    @StateObject private var model: PyConConsoleModel

    init(
        code: String,
        disabled: Bool = false,
        onResult: ((PyConRunResult) -> Void)? = nil,
        model: PyConConsoleModel? = nil
    ) {
        self.code = code
        self.disabled = disabled
        self.onResult = onResult
        _model = StateObject(wrappedValue: model ?? PyConConsoleModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            outputPanel
            if model.hasStarted { sandboxHost }
        }
        .background(Theme.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    /// Barre du haut : bouton d'exécution puis phrase d'aide.
    private var topBar: some View {
        HStack(alignment: .center, spacing: 9) {
            Button(action: {
                Task {
                    let value = await model.run(code)
                    onResult?(value)
                }
            }) {
                HStack(spacing: 6) {
                    if isBusy {
                        ProgressView().tint(Theme.surface)
                    } else {
                        IonIcon(name: "play", size: 14, color: Theme.surface)
                    }
                    Text(runLabel)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Theme.surface)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .opacity(isBlocked ? 0.4 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isBlocked)
            .accessibilityLabel(PyConLimits.accessibilityRunLabel)

            Text(model.hasStarted ? PyConLimits.deviceHint : PyConLimits.firstRunHint)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
    }

    /// Panneau de sortie : la sortie, l'erreur et la note sur fond sombre.
    @ViewBuilder
    private var outputPanel: some View {
        if let report = model.result?.report {
            ScrollView {
                VStack(alignment: .leading, spacing: 7) {
                    if !report.output.isEmpty {
                        Text(report.output)
                            .font(monoFont)
                            .foregroundStyle(Theme.surface)
                            .textSelection(.enabled)
                    }
                    if !report.error.isEmpty {
                        Text(report.error)
                            .font(monoFont)
                            .foregroundStyle(PyConLimits.errorColor)
                            .textSelection(.enabled)
                    }
                    if !report.note.isEmpty {
                        Text(report.note)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
            }
            .frame(maxHeight: PyConLimits.outputMaxHeight)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .padding(.horizontal, 9)
            .padding(.bottom, 9)
        }
    }

    /// Bac à sable hors écran (`PythonSandboxView.native.tsx`) : monté dès la
    /// première exécution, remonté quand `generation` change. Une WebView
    /// démontée rechargerait les dix mégaoctets de l'interpréteur à chaque appui.
    private var sandboxHost: some View {
        PyConSandboxHost(handle: model.sandbox, onMessage: model.handleMessage)
            .id(model.generation)
    }

    private var isBusy: Bool { model.phase != .idle }

    private var isBlocked: Bool {
        disabled || isBusy || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Libellé du bouton selon la phase (`Exécuter` / `Démarrage…` / `Exécution…`).
    private var runLabel: String {
        switch model.phase {
        case .starting: return PyConLimits.startingLabel
        case .running: return PyConLimits.runningLabel
        case .idle: return PyConLimits.runButtonLabel
        }
    }

    /// Texte monospace du panneau de sortie (source : `Menlo` 12).
    private var monoFont: Font { .custom("Menlo", size: 12) }
}
