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
//  - `expo_ref/src/components/PythonSandboxView.tsx` — WebView Pyodide, NON
//    portable : lue pour comprendre le protocole de messages (`run`/`result`).
//
//  CONTRAINTE NATIVE — aucun interpréteur Python n'est embarquable dans ce
//  portage iOS (pas de Pyodide, pas de WebView, pas de PythonKit). L'exécution
//  est donc SIMULÉE, de façon déterministe, par `PyConRunner` : seuls les appels
//  `print(…)` à argument littéral unique sont reconnus. La limite est affichée
//  dans l'interface (`PyConLimits.simulationNote`).
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
    /// Ce que le programme a écrit, `print` confondus.
    let output: String
    /// Message de syntaxe, trace ou cause de l'indisponibilité.
    let error: String
    /// Vrai quand la sortie a été coupée parce qu'elle devenait interminable.
    let truncated: Bool

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
    /// Temps laissé au programme avant d'être déclaré bouclé (`5 s`). La source
    /// prévoyait en plus un délai de démarrage de 120 s (`PYTHON_BOOT_TIMEOUT_MS`)
    /// pour télécharger l'interpréteur : sans interpréteur à charger, ce délai n'a
    /// plus d'objet et n'est pas porté.
    static let timeLimitSeconds = 5
    /// Garde-fou applicatif : une exécution figée ne répondrait plus du tout.
    static let runTimeoutMs = 20_000
    /// Longueur maximale de la sortie avant coupure.
    static let maxOutputLength = 20_000
    /// Hauteur maximale du panneau de sortie (points).
    static let outputMaxHeight: CGFloat = 190

    static let printToken = "print("
    static let commentPrefix = "#"
    static let breakLine = "break"
    static let whileTrueLine = "while True:"

    static let runButtonLabel = "Exécuter"
    static let startingLabel = "Démarrage de Python…"
    static let runningLabel = "Exécution…"
    static let deviceHint = "Ton programme tourne sur ton appareil : rien n’est envoyé."
    static let firstRunHint = "Première exécution : Python se télécharge une fois (environ 10 Mo)."
    static let accessibilityRunLabel = "Exécuter mon programme Python"
    static let simulationNote = "Exécution simulée : la console native ne simule que les print(…) littéraux."

    static let emptyProgramMessage = "Écris un programme avant de l’exécuter."
    static let timeoutMessage = "Ton programme tourne encore après \(timeLimitSeconds) secondes : il boucle sans doute sans fin."
    static let unsupportedMessage = "La console native n’embarque pas d’interpréteur Python : seuls les print(…) littéraux sont simulés. Cette instruction ne peut pas être exécutée ici."
    static let notRespondingMessage = "La console Python ne répond plus. Réessaie dans un instant."
    static let closedMessage = "Console Python fermée avant la fin."
    static let historyTitle = "Historique des exécutions"
    static let clearHistoryLabel = "Vider l’historique"
    static let historyOkLabel = "Sans erreur"
    static let historyErrorLabel = "Erreur"
    /// Nombre d'exécutions conservées dans l'historique.
    static let historyLimit = 8
    static let truncatedNote = "Sortie coupée : ton programme affiche trop de lignes."
    static let noOutputNote = "Programme exécuté sans erreur. Il n’affiche rien : ajoute un print(…) pour voir ton résultat."

    /// Couleur de l'erreur dans le panneau sombre (`#FF9A9E`).
    static let errorColor = Color(red: 1.0, green: 0.604, blue: 0.62)
}

// MARK: - Exécuteur simulé

/// Exécuteur **simulé**. Aucun interpréteur Python n'étant embarquable en natif,
/// `run` reconnaît un sous-ensemble déterministe du langage : lignes vides,
/// commentaires `#…`, lignes `break`, et `print(…)` à argument littéral unique
/// (chaîne `"…"` ou `'…'`, entier ou décimal). Toute autre instruction rend la
/// console indisponible avec un message qui explique la limite.
enum PyConRunner {
    static func run(_ source: String) -> PyConRunResult {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return PyConRunResult(status: .unavailable, output: "", error: PyConLimits.emptyProgramMessage, truncated: false)
        }

        let lines = source.components(separatedBy: .newlines)
        let hasEndlessLoop = lines.contains { $0.trimmingCharacters(in: .whitespaces) == PyConLimits.whileTrueLine }
        let hasBreak = lines.contains { $0.trimmingCharacters(in: .whitespaces) == PyConLimits.breakLine }
        if hasEndlessLoop && !hasBreak {
            return PyConRunResult(status: .timeout, output: "", error: PyConLimits.timeoutMessage, truncated: false)
        }

        var output = ""
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix(PyConLimits.commentPrefix) { continue }
            if line == PyConLimits.breakLine { continue }
            guard let piece = printLiteral(line) else {
                return PyConRunResult(status: .unavailable, output: "", error: PyConLimits.unsupportedMessage, truncated: false)
            }
            output += piece
        }

        var truncated = false
        if output.count > PyConLimits.maxOutputLength {
            truncated = true
            output = String(output.prefix(PyConLimits.maxOutputLength))
        }
        return PyConRunResult(status: .ok, output: output, error: "", truncated: truncated)
    }

    /// Rend le texte affiché par un appel `print(<littéral>)`, ou `nil` si la
    /// ligne n'est pas un tel appel (variable, f-string, concaténation, appel…).
    private static func printLiteral(_ line: String) -> String? {
        guard line.hasPrefix(PyConLimits.printToken), line.hasSuffix(")") else { return nil }
        let inner = String(line.dropFirst(PyConLimits.printToken.count).dropLast())
            .trimmingCharacters(in: .whitespaces)

        if let quote = inner.first, quote == "\"" || quote == "'", inner.count >= 2, inner.last == quote {
            let body = String(inner.dropFirst().dropLast())
            var escaped = false
            var singleLiteral = true
            for character in body {
                if escaped { escaped = false; continue }
                if character == "\\" { escaped = true; continue }
                if character == quote { singleLiteral = false; break }
            }
            if singleLiteral { return unescape(body) + "\n" }
        }

        if let number = numberText(inner) { return number + "\n" }
        return nil
    }

    /// Interprète les échappements d'une chaîne littérale (`\n`, `\t`, `\\`…).
    private static func unescape(_ body: String) -> String {
        var result = ""
        var pending = false
        for character in body {
            if pending {
                switch character {
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "r": result.append("\r")
                case "\\": result.append("\\")
                case "\"": result.append("\"")
                case "'": result.append("'")
                default:
                    result.append("\\")
                    result.append(character)
                }
                pending = false
            } else if character == "\\" {
                pending = true
            } else {
                result.append(character)
            }
        }
        if pending { result.append("\\") }
        return result
    }

    /// Rend la forme affichée d'un littéral numérique, ou `nil` si le texte
    /// n'est ni un entier ni un décimal.
    private static func numberText(_ text: String) -> String? {
        var body = Substring(text)
        if body.first == "-" || body.first == "+" { body = body.dropFirst() }
        guard !body.isEmpty, body.filter({ $0 == "." }).count <= 1 else { return nil }
        let digits = body.filter { $0 != "." }
        let allowed = CharacterSet(charactersIn: "0123456789")
        guard !digits.isEmpty, digits.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        if let value = Int(text) { return String(value) }
        if let value = Double(text) { return String(value) }
        return nil
    }
}

// MARK: - Historique des exécutions

/// Une exécution passée, conservée par la console. **Ajout du portage** : la
/// source Expo ne garde aucune trace des programmes exécutés.
struct PyConHistoryEntry: Identifiable {
    let id = UUID()
    let source: String
    let result: PyConRunResult
}

// MARK: - Modèle de la console

/// État de la console et point d'entrée des exécutions. Reprend le handle
/// impératif `run` de la source Expo : la soumission d'une réponse passe par
/// `run`, qui publie le résultat comme si l'élève avait appuyé sur « Exécuter ».
final class PyConConsoleModel: ObservableObject {
    @Published private(set) var result: PyConRunResult?
    @Published private(set) var phase: PyConPhase = .idle
    @Published private(set) var hasStarted = false
    /// Historique des exécutions, de la plus récente à la plus ancienne
    /// (**ajout du portage**).
    @Published private(set) var history: [PyConHistoryEntry] = []

    /// Jeton de l'exécution en cours : incrémenté à chaque lancement et à
    /// chaque annulation, ce qui rend caduc tout garde-fou déjà programmé.
    private var token = 0

    init() {}

    /// Équivalent `async` du handle `run` de la source Expo.
    func run(_ source: String) async -> PyConRunResult {
        runSynchronously(source)
    }

    /// Même exécution, sans `async` : un parent peut l'appeler directement et
    /// lire le résultat qu'elle renvoie.
    func runSynchronously(_ source: String) -> PyConRunResult {
        hasStarted = true
        phase = .starting
        token += 1
        let current = token
        armTimeout(current)
        phase = .running
        let value = PyConRunner.run(source)
        guard current == token else {
            return PyConRunResult(status: .unavailable, output: "", error: PyConLimits.closedMessage, truncated: false)
        }
        result = value
        phase = .idle
        history.insert(PyConHistoryEntry(source: source, result: value), at: 0)
        if history.count > PyConLimits.historyLimit {
            history.removeLast(history.count - PyConLimits.historyLimit)
        }
        return value
    }

    /// Annule l'exécution en cours : la console est fermée avant la fin.
    func cancelPendingRun() {
        token += 1
        phase = .idle
        result = PyConRunResult(status: .unavailable, output: "", error: PyConLimits.closedMessage, truncated: false)
    }

    /// Garde-fou : au-delà de `PyConLimits.runTimeoutMs`, si l'exécution n'est
    /// pas terminée, la console se déclare muette et remet la phase à `idle`.
    private func armTimeout(_ current: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(PyConLimits.runTimeoutMs)) { [weak self] in
            guard let self = self, self.token == current, self.phase != .idle else { return }
            self.token += 1
            self.result = PyConRunResult(status: .unavailable, output: "", error: PyConLimits.notRespondingMessage, truncated: false)
            self.phase = .idle
        }
    }

    /// Vide l'historique des exécutions (**ajout du portage**).
    func clearHistory() {
        history = []
    }
}

// MARK: - Vue

/// Console Python affichée sous le champ de réponse : un bouton « Exécuter »,
/// la sortie du programme, ses erreurs et sa note. L'exécution est simulée en
/// natif (voir `PyConRunner`) ; la limite est annoncée à l'écran.
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
            simulationNotice
            if !model.history.isEmpty { historySection }
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
                let value = model.runSynchronously(code)
                onResult?(value)
            }) {
                HStack(spacing: 6) {
                    if isBusy {
                        ProgressView().tint(Theme.surface)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
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

    /// Mention qui documente la simulation, toujours visible.
    private var simulationNotice: some View {
        Text(PyConLimits.simulationNote)
            .font(.system(size: 11))
            .foregroundStyle(Theme.inkFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.bottom, 9)
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

    /// Historique des exécutions — **ajout du portage** : la source Expo ne
    /// garde aucune trace des programmes exécutés. Chaque entrée rappelle le
    /// programme et le verdict rendu.
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(PyConLimits.historyTitle)
                    .font(.system(size: 11, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkFaint)
                Spacer(minLength: 8)
                Button(PyConLimits.clearHistoryLabel) { model.clearHistory() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
            }
            ForEach(model.history) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.source.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    Text(entry.result.report.error.isEmpty ? PyConLimits.historyOkLabel : PyConLimits.historyErrorLabel)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(entry.result.report.error.isEmpty ? Theme.progress : Theme.like)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.bottom, 9)
    }

    /// Texte monospace du panneau de sortie (source : `Menlo` 12).
    private var monoFont: Font { .custom("Menlo", size: 12) }
}
