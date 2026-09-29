//
//  MathKeyboardViewCore.swift
//  Duello
//
//  Clavier mathématique — coquille de `MathKeyboardView` : contrat
//  d'intégration, état, corps, frappe et outils partagés. Le rendu est
//  réparti dans `MathKeyboardView+Toolbar.swift`, `+Keys.swift`,
//  `+MatrixEditor.swift`, `+OperatorEditor.swift`, `+IntervalEditor.swift` ;
//  les modèles et données dans `MathKbKeyboardModel.swift`,
//  `MathKbLayout.swift`, `MathKbScript.swift`, `MathKbOperatorCatalog.swift`,
//  `MathKbInterval.swift`, `MathKbMatrixFormatter.swift`, `MathKbDrafts.swift`,
//  `MathKbControls.swift` et `MathKbFlowLayout.swift`.
//
//  Fichiers source portés :
//  - `expo_ref/src/components/MathKeyboard.tsx` — composant `MathKeyboard`,
//    touche `MathKey`, bornes infinies `InfiniteBoundKeys`, éditeurs guidés
//    (matrice, opérateur, intervalle), bandeau d'onglets, rangée d'actions
//    espace / retour / effacer ;
//  - `expo_ref/src/utils/mathKeySections.ts` — `MATH_SECTIONS`,
//    `MATH_KEYBOARD_SECTIONS`, `PYTHON_SECTIONS`, `SUBSCRIPT_SECTIONS` ;
//  - `expo_ref/src/utils/mathKeyboardLayout.ts` — `PYTHON_KEYBOARD_KEYS` ;
//  - `expo_ref/src/utils/mathOperator.ts` — `MATH_OPERATOR_DEFINITIONS`,
//    `INFINITE_BOUNDS`, `formatMathOperator`, `isMathOperatorComplete` ;
//  - `expo_ref/src/utils/mathInterval.ts` — `intervalBrackets`,
//    `formatInterval`, `isInfiniteBound` ;
//  - `expo_ref/src/utils/mathMatrix.ts` — `formatMatrix`, `matrixSides` ;
//  - `expo_ref/src/utils/mathLayout.ts` — `SUPERSCRIPTS`, `SUBSCRIPTS`,
//    `toScript`.
//
//  Spécification de portage : `mk_spec_logic.md` (racine du workspace).
//
//  Notes de portage
//  ----------------
//  - Le clavier insère de l'**Unicode** natif (`∑`, `∫`, `ₙ`, `²`…) et ne
//    convertit aucun LaTeX : comme dans la source, il n'appelle jamais
//    `LatexToUnicode` (voir `mk_spec_logic.md` §3.1).
//  - Le clavier ne se positionne pas lui-même : pas d'`absolute`, pas d'insets,
//    pas de `KeyboardAvoidingView` interne. C'est l'écran parent qui décide du
//    placement (les trois schémas sont décrits au §1.4 de la spécification).
//  - La signature d'intégration `init(mode:onInsert:onBackspace:onClose:)` ne
//    transporte que le texte : les touches qui reculent le curseur après
//    insertion (`back`, ex. `()`, `{}`, `√()`) perdent ce recul. Les variantes
//    `init(mode:onInsertWithBack:…)` (recul) et
//    `init(mode:answer:onInsertWithRange:…)` (recul + plage visée) le
//    transmettent.
//  - Édition d'une construction **déjà écrite** (« Modifier … »,
//    `MathKeyboard.tsx:457-478,498-508,1038-1060`) : `startTool` relit la
//    réponse (`findMatrixAtSelection` / `findMathOperatorAtSelection`) et rouvre
//    l'éditeur avec la construction visée (`replacement`) ; à la validation,
//    `insertText` porte la plage pour la **remplacer** au lieu d'en insérer une
//    seconde (`commitMatrix`, `commitOperator`). Le contrat complet est
//    `init(mode:answer:onInsertWithRange:onBackspace:onClose:suggestions:)`.
//  - Écart assumé (2026-09-29) — **Plateforme** : iOS 16 n'expose pas la
//    sélection d'un `TextField` ; le curseur n'est pas suivi sans un champ
//    `UIViewRepresentable`. Le contrat ne transporte donc que la réponse
//    (`answer`), pas la sélection : le curseur est réputé **en fin** de champ
//    (la saisie s'ajoute toujours en fin de réponse), et une construction en
//    **milieu** de texte n'est pas rouverte.
//  - SwiftUI iOS 16 n'expose pas la sélection d'un `TextField`. Là où la source
//    suivait un curseur par champ (`CaretText` : `insertAtCaret` /
//    `deleteAtCaret`, §2.1), les touches maths **s'ajoutent en fin** du champ
//    actif et l'effacement retire son dernier caractère. Les chevrons et la
//    touche retour déplacent le champ actif, pas le curseur.
//  - La rangée de suggestions « propres à l'exercice » (`suggestions` /
//    `pinnedKeys`) est portée : `MathKeyboardView` l'affiche à partir du
//    paramètre `suggestions` fourni par l'appelant, qui en calcule le contenu.
//
//  Extrait de `MathKeyboardView.swift` : découpage en modules, sans
//  renommage de type, de membre ni de signature.
//

import SwiftUI

// MARK: - Clavier

/// Barre de symboles mathématiques, posée par l'écran parent au-dessus du
/// clavier système (les deux cohabitent : lettres et chiffres en bas, symboles
/// ici). Portée depuis `components/MathKeyboard.tsx`.
///
/// ```swift
/// MathKeyboardView(
///     mode: .math,
///     onInsert: { texte in réponse.insert(texte) },
///     onBackspace: { réponse.deleteBackward() },
///     onClose: { clavierOuvert = false }
/// )
/// ```
struct MathKeyboardView: View {

    // MARK: Contrat d'intégration

    private let mode: MathKbMode
    /// Réponse courante, relue à l'ouverture d'un outil pour rouvrir une
    /// construction déjà écrite (`MathKeyboard.tsx:457-478`). Vide : les outils
    /// insèrent toujours une construction neuve.
    let answer: String
    /// Insère `text`, recule le curseur de `back` et remplace la plage
    /// `replacement` (`onInsert(text, back, replacement)`).
    private let insertRange: (String, Int, StmtTextSelection?) -> Void
    private let backspace: () -> Void
    let close: () -> Void

    /// Touches suggérées pour l'exercice en cours (rangée `pinnedKeys` du RN),
    /// posées en tête du clavier. Vide : aucune rangée. Le calcul reste à
    /// l'appelant (`KbSupSuggestions`).
    let suggestions: [MathKbKey]

    /// Signature d'intégration : `onInsert` ne transporte que le texte. Les
    /// touches à recul de curseur (`back`) sont insérées sans ce recul ; pour le
    /// conserver, utiliser `init(mode:onInsertWithBack:onBackspace:onClose:)`.
    init(
        mode: MathKbMode,
        onInsert: @escaping (String) -> Void,
        onBackspace: @escaping () -> Void,
        onClose: @escaping () -> Void,
        suggestions: [MathKbKey] = []
    ) {
        self.mode = mode
        self.answer = ""
        self.insertRange = { text, _, _ in onInsert(text) }
        self.backspace = onBackspace
        self.close = onClose
        self.suggestions = suggestions
        _sectionId = State(initialValue: MathKbLayout.initialSectionId(for: mode))
    }

    /// Variante qui transmet aussi le recul du curseur demandé par la touche
    /// (`back`), pour se placer entre les délimiteurs après un `()` ou un `{}`.
    init(
        mode: MathKbMode,
        onInsertWithBack: @escaping (String, Int) -> Void,
        onBackspace: @escaping () -> Void,
        onClose: @escaping () -> Void,
        suggestions: [MathKbKey] = []
    ) {
        self.mode = mode
        self.answer = ""
        self.insertRange = { text, back, _ in onInsertWithBack(text, back) }
        self.backspace = onBackspace
        self.close = onClose
        self.suggestions = suggestions
        _sectionId = State(initialValue: MathKbLayout.initialSectionId(for: mode))
    }

    /// Signature complète : `answer` est la réponse courante (pour rouvrir une
    /// construction écrite) et `onInsert` reçoit la plage visée (`replacement`)
    /// que l'appelant applique pour **remplacer** au lieu de dupliquer.
    init(
        mode: MathKbMode,
        answer: String,
        onInsertWithRange: @escaping (String, Int, StmtTextSelection?) -> Void,
        onBackspace: @escaping () -> Void,
        onClose: @escaping () -> Void,
        suggestions: [MathKbKey] = []
    ) {
        self.mode = mode
        self.answer = answer
        self.insertRange = onInsertWithRange
        self.backspace = onBackspace
        self.close = onClose
        self.suggestions = suggestions
        _sectionId = State(initialValue: MathKbLayout.initialSectionId(for: mode))
    }

    // MARK: État

    @State var sectionId: String
    @State var subscriptMode = false
    @State var matrixDraft: MathKbMatrixDraft?
    @State var operatorDraft: MathKbOperatorDraft?
    @State var intervalDraft: MathKbIntervalDraft?

    @FocusState var matrixFocus: Int?
    @FocusState var operatorFocus: Int?
    @FocusState var intervalFocus: Int?

    // MARK: Dérivés

    var sections: [MathKbSection] { MathKbLayout.sections(for: mode) }

    var currentSection: MathKbSection {
        sections.first { $0.id == sectionId } ?? sections[0]
    }

    /// Un outil guidé est ouvert : il absorbe la frappe et la rangée de touches
    /// s'affiche un peu plus basse.
    var draftOpen: Bool {
        matrixDraft != nil || operatorDraft != nil || intervalDraft != nil
    }

    /// Le mode indice n'existe que là où les caractères ont une forme basse.
    var lowering: Bool {
        subscriptMode && currentSection.id == MathKbLayout.subscriptSectionId
    }

    /// Curseur de la réponse. iOS 16 n'expose pas la sélection d'un `TextField` :
    /// la saisie s'ajoutant toujours en fin de champ, le curseur est réputé à la
    /// fin de la réponse (`MathKeyboard.tsx:457-478`).
    var answerSelection: StmtTextSelection {
        StmtTextSelection(start: answer.count, end: answer.count)
    }

    // MARK: Corps

    var body: some View {
        VStack(spacing: 0) {
            tabsRow

            // Rangée de suggestions de l'exercice (`pinnedKeys` du RN) : affichée
            // seulement hors éditeur guidé et si l'appelant fournit des touches.
            if !draftOpen, !suggestions.isEmpty {
                KbSupSuggestionsRow(
                    keys: suggestions,
                    onInsert: { texte, recul in insertDraftText(texte, back: recul) },
                    onAction: { action in startTool(action) },
                    lowering: lowering
                )
            }

            if let draft = matrixDraft {
                matrixEditor(draft)
            }
            if let draft = operatorDraft {
                operatorEditor(draft)
            }
            if let draft = intervalDraft {
                intervalEditor(draft)
            }

            keysScroll
            actionsRow
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background(Theme.surfaceMuted)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
    }

    // MARK: Frappe

    /// Insère `text` dans la réponse ; `back` recule le curseur d'autant et
    /// `replacement` désigne la construction à remplacer (`nil` = insertion
    /// neuve). Les appels qui ne visent aucune plage gardent la forme à deux
    /// arguments (`insertText(text, back)`).
    func insertText(_ text: String, _ back: Int, _ replacement: StmtTextSelection? = nil) {
        insertRange(text, back, replacement)
    }

    /// Ouvre un outil guidé — un seul à la fois, sinon deux panneaux se
    /// disputeraient les touches (`startTool`). La réponse est relue pour
    /// rouvrir une construction déjà écrite (`findMatrixAtSelection` /
    /// `findMathOperatorAtSelection`) et poser sa plage (`replacement`).
    func startTool(_ action: MathKbAction) {
        matrixDraft = nil
        operatorDraft = nil
        intervalDraft = nil

        switch action {
        case .matrix:
            matrixDraft = matrixDraft(from: StmtMatrixParse.findMatrixAtSelection(answer, answerSelection))
            matrixFocus = 0
        case .interval:
            intervalDraft = MathKbIntervalDraft.initial()
            intervalFocus = 0
        case .exponent, .limit, .integral, .sum, .product:
            guard let kind = operatorKind(for: action) else { return }
            operatorDraft = operatorDraft(from: kind)
            operatorFocus = 0
        }
    }

    /// Brouillon de matrice pour l'outil ouvert (`createMatrixDraft`,
    /// `MathKeyboard.tsx:161-189`) : une matrice écrite sous le curseur est
    /// rouverte avec ses cases, son délimiteur et sa plage ; sinon une grille
    /// 2 × 2 vide.
    func matrixDraft(from parsed: StmtParsedMatrix?) -> MathKbMatrixDraft {
        guard
            let parsed,
            (MathKbLayout.matrixMinSize...MathKbLayout.matrixMaxSize).contains(parsed.rows.count),
            let firstRow = parsed.rows.first,
            (MathKbLayout.matrixMinSize...MathKbLayout.matrixMaxSize).contains(firstRow.count)
        else { return MathKbMatrixDraft.initial() }

        let delimiter: MathKbMatrixDelimiter
        switch parsed.delimiter {
        case .square: delimiter = .square
        case .round: delimiter = .round
        case .braces: delimiter = .braces
        case .leftBrace: delimiter = .leftBrace
        case .bars: delimiter = .bars
        case .doubleBars: delimiter = .doubleBars
        case .none: delimiter = .none
        }
        return MathKbMatrixDraft(
            rows: parsed.rows.count,
            columns: firstRow.count,
            cells: parsed.rows.flatMap { $0 },
            active: 0,
            delimiter: delimiter,
            replacement: parsed.range
        )
    }

    /// Brouillon d'opérateur pour l'outil ouvert (`createMathOperatorDraft`,
    /// `MathKeyboard.tsx:191-210`) : une construction écrite sous le curseur est
    /// rouverte avec ses champs et sa plage ; sinon les champs sont vides.
    func operatorDraft(from kind: MathKbOperatorKind) -> MathKbOperatorDraft {
        guard
            let expected = StmtMathOperatorKind(rawValue: kind.rawValue),
            let parsed = StmtOperatorParse.findMathOperatorAtSelection(answer, answerSelection, expected)
        else { return MathKbOperatorDraft(kind: kind) }
        return MathKbOperatorDraft(kind: kind, values: parsed.values, replacement: parsed.range)
    }

    /// Une touche pressée alors qu'un outil est ouvert écrit dans son champ
    /// actif ; sinon l'insertion part vers la réponse, avec le recul demandé.
    func insertDraftText(_ text: String, back: Int = 0) {
        if var draft = matrixDraft, draft.active < draft.cells.count {
            draft.cells[draft.active] += text
            matrixDraft = draft
            return
        }
        if var draft = operatorDraft, draft.active < draft.values.count {
            draft.values[draft.active] += text
            operatorDraft = draft
            return
        }
        if var draft = intervalDraft {
            if draft.active == 0 { draft.lower += text } else { draft.upper += text }
            intervalDraft = draft
            return
        }
        insertText(text, back)
    }

    /// Efface le dernier caractère du champ actif, ou délègue à la réponse.
    func handleBackspace() {
        if var draft = matrixDraft, draft.active < draft.cells.count {
            if !draft.cells[draft.active].isEmpty { draft.cells[draft.active].removeLast() }
            matrixDraft = draft
            return
        }
        if var draft = operatorDraft, draft.active < draft.values.count {
            if !draft.values[draft.active].isEmpty { draft.values[draft.active].removeLast() }
            operatorDraft = draft
            return
        }
        if var draft = intervalDraft {
            if draft.active == 0 {
                if !draft.lower.isEmpty { draft.lower.removeLast() }
            } else if !draft.upper.isEmpty {
                draft.upper.removeLast()
            }
            intervalDraft = draft
            return
        }
        backspace()
    }

    /// Touche retour contextuelle (`handleReturn`) : champ suivant, borne
    /// suivante, case suivante, sinon une nouvelle ligne.
    func handleReturn() {
        if let draft = operatorDraft {
            focusOperatorField(draft.active + 1)
            return
        }
        if intervalDraft != nil {
            moveIntervalBound(1)
            return
        }
        if matrixDraft != nil {
            moveMatrixCell(1)
            return
        }
        insertText("\n", 0)
    }

    // MARK: Outils

    /// Décale la section active de `step` (+1 suivante, -1 précédente),
    /// bornée aux extrémités comme le RN PanResponder.
    func shiftSection(_ step: Int) {
        guard let currentIndex = sections.firstIndex(where: { $0.id == currentSection.id }) else { return }
        let nextIndex = max(0, min(sections.count - 1, currentIndex + step))
        guard nextIndex != currentIndex else { return }
        sectionId = sections[nextIndex].id
    }

    /// Geste de balayage horizontal sur la grille de touches (portage PanResponder
    /// RN : seuil dx 14, déclenchement si |dx| > 46 ou vélocité approximée via
    /// `predictedEndTranslation`).
    var sectionSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                // Réclamation : déplacement franc et dominante horizontale
                // (|dx| > 14 et |dx| > |dy| * 1.5, comme le RN).
                guard abs(dx) > 14, abs(dx) > abs(dy) * 1.5 else { return }
                let predictedDx = value.predictedEndTranslation.width
                // Déclenchement si déplacement suffisant ou élan marqué.
                let triggered = abs(dx) > 46 || abs(predictedDx) > 80
                guard triggered else { return }
                shiftSection(dx < 0 ? 1 : -1)
            }
    }

    func operatorKind(for action: MathKbAction?) -> MathKbOperatorKind? {
        guard let action = action else { return nil }
        switch action {
        case .exponent: return .exponent
        case .limit: return .limit
        case .integral: return .integral
        case .sum: return .sum
        case .product: return .product
        case .matrix, .interval: return nil
        }
    }

    // MARK: Bornes infinies

    /// Bornes infinies posées à côté du champ ouvert (`InfiniteBoundKeys`) :
    /// elles ne sont pas une touche de plus dans une section.
    func infiniteBoundKeys(target: String) -> some View {
        HStack(spacing: 5) {
            Text("Borne infinie")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
            ForEach(MathKbLayout.infiniteBounds, id: \.self) { bound in
                Button {
                    insertDraftText(bound)
                } label: {
                    Text(bound)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 9)
                        .frame(minWidth: 46)
                }
                .buttonStyle(MathKbPressStyle(
                    background: Theme.primaryLight,
                    border: Theme.primary,
                    capsule: true
                ))
                .accessibilityLabel(
                    "Écrire \(bound == "+∞" ? "plus l’infini" : "moins l’infini") dans le champ \(target)"
                )
            }
        }
    }
}
